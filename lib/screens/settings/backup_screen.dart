import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_menu.dart';
import '../../widgets/dos_screen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backup = BackupService.instance;
  final _drive = GoogleDriveService.instance;
  final _auth = AuthService.instance;
  String _status = 'Choisissez une option de sauvegarde.';
  bool _busy = false;

  List<String> get _items {
    final items = <String>[
      'SAUVEGARDER VERS UN DOSSIER',
      'SAUVEGARDER VERS LECTEUR EXTERNE (USB)',
      'SAUVEGARDER VERS GOOGLE DRIVE (EN LIGNE)',
      'CONFIGURER GOOGLE DRIVE (OAuth)',
    ];
    if (_auth.isAdmin) {
      items.add('RESTAURER DEPUIS FICHIER LOCAL');
      items.add('RESTAURER DEPUIS GOOGLE DRIVE');
    }
    items.add('RETOUR AU MENU');
    return items;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Opération en cours...';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
        setState(() => _status = 'Échec de l\'opération.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupToFolder() async {
    await _run(() async {
      final folder = await _backup.pickFolder();
      if (folder == null) {
        setState(() => _status = 'Sauvegarde annulée.');
        return;
      }
      final path = await _backup.backupToDirectory(folder);
      if (!mounted) return;
      setState(() => _status = 'Sauvegarde OK:\n$path');
      await DosDialog.info(
        context,
        title: 'Sauvegarde',
        message: 'Base sauvegardée avec succès.\n\n$path',
      );
    });
  }

  Future<void> _backupToUsb() async {
    await _run(() async {
      final drives = await _backup.listRemovableDrives();
      if (drives.isEmpty) {
        if (!mounted) return;
        await DosDialog.error(
          context,
          title: 'Lecteur externe',
          message:
              'Aucun lecteur USB / amovible détecté.\n'
              'Branchez un support puis réessayez.',
        );
        setState(() => _status = 'Aucun lecteur amovible.');
        return;
      }

      if (!mounted) return;
      String? chosen = drives.length == 1
          ? drives.first
          : await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => _PathPickDialog(
                title: 'LECTEUR USB',
                items: drives,
              ),
            );
      if (chosen == null) {
        setState(() => _status = 'Sauvegarde annulée.');
        return;
      }

      final path = await _backup.backupToDirectory(chosen);
      if (!mounted) return;
      setState(() => _status = 'Sauvegarde USB OK:\n$path');
      await DosDialog.info(
        context,
        title: 'Sauvegarde USB',
        message: 'Base sauvegardée sur $chosen\n\n$path',
      );
    });
  }

  Future<void> _configureDrive() async {
    await _run(() async {
      final values = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _OAuthConfigSheet(),
      );
      if (values == null) {
        setState(() => _status = 'Configuration annulée.');
        return;
      }
      await _drive.saveOAuthClient(
        values['CLIENT ID'] ?? '',
        values['CLIENT SECRET'] ?? '',
      );
      await _drive.signOut();
      if (!mounted) return;
      setState(() => _status = 'Identifiants Google Drive enregistrés.');
      await DosDialog.info(
        context,
        title: 'Google Drive',
        message: 'Client OAuth enregistré. La prochaine sauvegarde\n'
            'ouvrira le navigateur pour autoriser Drive.',
      );
    });
  }

  Future<void> _backupToGoogleDriveOnline() async {
    await _run(() async {
      if (!await _drive.isConfigured) {
        if (!mounted) return;
        await DosDialog.info(
          context,
          title: 'Google Drive',
          message:
              'Configurez d\'abord Client ID / Secret\n'
              '(option CONFIGURER GOOGLE DRIVE).',
        );
        setState(() => _status = 'Google Drive non configuré.');
        return;
      }

      setState(() =>
          _status = 'Connexion Google...\nAutorisez l\'accès dans le navigateur.');
      final dbPath = await _backup.databasePath;
      await _backup.checkpointForUpload();
      final name = await _drive.uploadDatabaseBackup(dbPath);
      if (!mounted) return;
      setState(() => _status = 'Upload Drive OK:\n$name');
      await DosDialog.info(
        context,
        title: 'Google Drive',
        message:
            'Sauvegarde envoyée en ligne dans le dossier\n'
            'STORA_Backups de votre Google Drive.\n\n$name',
      );
    });
  }

  Future<void> _restoreLocal() async {
    if (!_auth.isAdmin) return;
    await _run(() async {
      final confirm = await DosDialog.confirm(
        context,
        title: 'Restaurer',
        message:
            'ATTENTION : la base actuelle sera remplacée.\nContinuer ?',
      );
      if (confirm != true) {
        setState(() => _status = 'Restauration annulée.');
        return;
      }
      final file = await _backup.pickBackupFile();
      if (file == null) {
        setState(() => _status = 'Restauration annulée.');
        return;
      }
      await _backup.restoreFromFile(file);
      if (!mounted) return;
      setState(() => _status = 'Restauration locale OK.');
      await DosDialog.info(
        context,
        title: 'Restauration',
        message: 'Base restaurée. Déconnectez-vous si besoin.',
      );
    });
  }

  Future<void> _restoreDrive() async {
    if (!_auth.isAdmin) return;
    await _run(() async {
      if (!await _drive.isConfigured) {
        if (!mounted) return;
        await DosDialog.info(
          context,
          title: 'Google Drive',
          message: 'Configurez d\'abord Client ID / Secret OAuth.',
        );
        return;
      }

      if (!mounted) return;
      final confirm = await DosDialog.confirm(
        context,
        title: 'Restaurer Drive',
        message:
            'ATTENTION : la base actuelle sera remplacée\n'
            'par une sauvegarde cloud. Continuer ?',
      );
      if (confirm != true) {
        setState(() => _status = 'Restauration annulée.');
        return;
      }

      setState(() => _status = 'Liste des sauvegardes Drive...');
      final files = await _drive.listBackups();
      if (files.isEmpty) {
        if (!mounted) return;
        await DosDialog.error(
          context,
          title: 'Google Drive',
          message: 'Aucune sauvegarde STORA sur Drive.',
        );
        return;
      }

      if (!mounted) return;
      final chosen = await showDialog<DriveBackupFile>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DriveListDialog(files: files),
      );
      if (chosen == null) {
        setState(() => _status = 'Restauration annulée.');
        return;
      }

      final temp =
          await _drive.downloadBackupToTemp(chosen.id, chosen.name);
      await _backup.restoreFromFile(temp);
      if (!mounted) return;
      setState(() => _status = 'Restauration Drive OK.');
      await DosDialog.info(
        context,
        title: 'Restauration',
        message: 'Base restaurée depuis Drive :\n${chosen.name}',
      );
    });
  }

  Future<void> _onSelect(int index) async {
    final label = _items[index];
    switch (label) {
      case 'SAUVEGARDER VERS UN DOSSIER':
        await _backupToFolder();
      case 'SAUVEGARDER VERS LECTEUR EXTERNE (USB)':
        await _backupToUsb();
      case 'SAUVEGARDER VERS GOOGLE DRIVE (EN LIGNE)':
        await _backupToGoogleDriveOnline();
      case 'CONFIGURER GOOGLE DRIVE (OAuth)':
        await _configureDrive();
      case 'RESTAURER DEPUIS FICHIER LOCAL':
        await _restoreLocal();
      case 'RESTAURER DEPUIS GOOGLE DRIVE':
        await _restoreDrive();
      case 'RETOUR AU MENU':
        if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'SAUVEGARDE / RESTAURATION',
      subtitle: 'Dossier, USB ou Google Drive en ligne (API)',
      helpLines: const [
        '↑↓ Entrée : choisir | ECHAP : retour',
        'Drive en ligne = upload cloud (pas le dossier local)',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'OPTIONS',
              child: DosMenu(
                items: _items,
                onSelect: _onSelect,
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'ÉTAT',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_status, style: DosTheme.text()),
                  const SizedBox(height: 16),
                  Text(
                    'Google Drive API :\n'
                    '1) Activer Google Drive API\n'
                    '2) Créer OAuth « Application de bureau »\n'
                    '3) Configurer Client ID / Secret ici\n'
                    '4) Autoriser une fois dans le navigateur',
                    style: DosTheme.dim(size: 12),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    Text('Veuillez patienter...',
                        style: DosTheme.text(weight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OAuthConfigSheet extends StatefulWidget {
  const _OAuthConfigSheet();

  @override
  State<_OAuthConfigSheet> createState() => _OAuthConfigSheetState();
}

class _OAuthConfigSheetState extends State<_OAuthConfigSheet> {
  final _idCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 640,
          constraints: const BoxConstraints(maxHeight: 480),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DosColors.background,
            border: Border.all(color: DosColors.border, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GOOGLE DRIVE OAUTH', style: DosTheme.title(size: 18)),
              const SizedBox(height: 8),
              Text(
                'Client ID et Secret (Google Cloud → Bureau).',
                style: DosTheme.dim(),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: DosForm(
                    submitLabel: 'ENREGISTRER [F10]',
                    onCancel: () => Navigator.pop(context),
                    onSubmit: (values) {
                      final id = values['CLIENT ID']?.trim() ?? '';
                      final secret = values['CLIENT SECRET']?.trim() ?? '';
                      if (id.isEmpty || secret.isEmpty) return;
                      Navigator.pop(context, values);
                    },
                    fields: [
                      DosFormField(
                          label: 'CLIENT ID',
                          controller: _idCtrl,
                          required: true),
                      DosFormField(
                          label: 'CLIENT SECRET',
                          controller: _secretCtrl,
                          required: true,
                          obscure: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathPickDialog extends StatefulWidget {
  const _PathPickDialog({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  State<_PathPickDialog> createState() => _PathPickDialogState();
}

class _PathPickDialogState extends State<_PathPickDialog> {
  late final FocusNode _focus;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp:
            setState(() =>
                _selected = (_selected - 1).clamp(0, widget.items.length - 1));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowDown:
            setState(() =>
                _selected = (_selected + 1).clamp(0, widget.items.length - 1));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.enter:
          case LogicalKeyboardKey.numpadEnter:
            Navigator.pop(context, widget.items[_selected]);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(color: DosColors.border, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: DosTheme.title(size: 18)),
                const SizedBox(height: 12),
                ...List.generate(widget.items.length, (i) {
                  final selected = i == _selected;
                  return Container(
                    width: double.infinity,
                    color: selected ? DosColors.highlight : null,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(widget.items[i],
                        style: DosTheme.text(weight: FontWeight.bold)),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriveListDialog extends StatefulWidget {
  const _DriveListDialog({required this.files});

  final List<DriveBackupFile> files;

  @override
  State<_DriveListDialog> createState() => _DriveListDialogState();
}

class _DriveListDialogState extends State<_DriveListDialog> {
  late final FocusNode _focus;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp:
            setState(() =>
                _selected = (_selected - 1).clamp(0, widget.files.length - 1));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowDown:
            setState(() =>
                _selected = (_selected + 1).clamp(0, widget.files.length - 1));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.enter:
          case LogicalKeyboardKey.numpadEnter:
            Navigator.pop(context, widget.files[_selected]);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(color: DosColors.border, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SAUVEGARDES DRIVE', style: DosTheme.title(size: 18)),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.files.length,
                    itemBuilder: (_, i) {
                      final selected = i == _selected;
                      return Container(
                        color: selected ? DosColors.highlight : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(widget.files[i].label,
                            style: DosTheme.text(weight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
