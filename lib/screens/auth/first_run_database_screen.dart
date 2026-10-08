import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../services/app_exit.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_menu.dart';
import '../../widgets/dos_screen.dart';
import 'login_screen.dart';
import 'setup_admin_screen.dart';

/// Affiché uniquement si aucune base locale n'existe encore.
class FirstRunDatabaseScreen extends StatefulWidget {
  const FirstRunDatabaseScreen({super.key});

  @override
  State<FirstRunDatabaseScreen> createState() => _FirstRunDatabaseScreenState();
}

class _FirstRunDatabaseScreenState extends State<FirstRunDatabaseScreen> {
  final _backup = BackupService.instance;
  final _drive = GoogleDriveService.instance;
  String _status =
      'Aucune base locale détectée.\nChoisissez comment démarrer STORA.';
  bool _busy = false;

  static const _items = [
    'NOUVELLE INSTALLATION (base vide)',
    'CHARGER UNE SAUVEGARDE LOCALE / USB',
    'CHARGER DEPUIS GOOGLE DRIVE (EN LIGNE)',
    'CONFIGURER GOOGLE DRIVE (OAuth)',
    'QUITTER STORA',
  ];

  Future<void> _goToAuth() async {
    await DatabaseHelper.instance.database;
    final hasAdmin = await AuthService.instance.hasAdmin();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            hasAdmin ? const LoginScreen() : const SetupAdminScreen(),
      ),
    );
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
        setState(() => _status = 'Échec. Réessayez ou créez une nouvelle base.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newInstall() async {
    await _run(() async {
      await DatabaseHelper.instance.database;
      if (!mounted) return;
      setState(() => _status = 'Nouvelle base créée.');
      await _goToAuth();
    });
  }

  Future<void> _restoreLocal() async {
    await _run(() async {
      final file = await _backup.pickBackupFile();
      if (file == null) {
        setState(() => _status = 'Chargement annulé.');
        return;
      }
      await DatabaseHelper.instance.installFromBackupFile(file);
      if (!mounted) return;
      setState(() => _status = 'Sauvegarde chargée.');
      await DosDialog.info(
        context,
        title: 'Restauration',
        message: 'Base restaurée depuis :\n$file',
      );
      await _goToAuth();
    });
  }

  Future<void> _configureDrive() async {
    await _run(() async {
      final values = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _OAuthConfigDialog(),
      );
      if (values == null) {
        setState(() => _status = 'Configuration annulée.');
        return;
      }
      await _drive.saveOAuthClient(
        values['CLIENT ID'] ?? '',
        values['CLIENT SECRET'] ?? '',
      );
      if (!mounted) return;
      setState(() => _status = 'Identifiants Google Drive enregistrés.');
      await DosDialog.info(
        context,
        title: 'Google Drive',
        message:
            'Client OAuth enregistré.\n'
            'Vous pouvez maintenant charger une sauvegarde en ligne.',
      );
    });
  }

  Future<void> _restoreFromDrive() async {
    await _run(() async {
      if (!await _drive.isConfigured) {
        if (!mounted) return;
        await DosDialog.info(
          context,
          title: 'Google Drive',
          message:
              'Configurez d\'abord le Client ID / Secret OAuth\n'
              '(option CONFIGURER GOOGLE DRIVE).',
        );
        setState(() => _status = 'Google Drive non configuré.');
        return;
      }

      setState(() => _status = 'Connexion Google Drive...\nAutorisez dans le navigateur.');
      final files = await _drive.listBackups();
      if (files.isEmpty) {
        if (!mounted) return;
        await DosDialog.error(
          context,
          title: 'Google Drive',
          message: 'Aucune sauvegarde STORA trouvée sur Drive.',
        );
        setState(() => _status = 'Aucune sauvegarde sur Drive.');
        return;
      }

      if (!mounted) return;
      final chosen = await showDialog<DriveBackupFile>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DriveFilePickDialog(files: files),
      );
      if (chosen == null) {
        setState(() => _status = 'Chargement annulé.');
        return;
      }

      setState(() => _status = 'Téléchargement de ${chosen.name}...');
      final tempPath =
          await _drive.downloadBackupToTemp(chosen.id, chosen.name);
      await DatabaseHelper.instance.installFromBackupFile(tempPath);
      if (!mounted) return;
      setState(() => _status = 'Sauvegarde Drive restaurée.');
      await DosDialog.info(
        context,
        title: 'Google Drive',
        message: 'Base restaurée depuis le cloud :\n${chosen.name}',
      );
      await _goToAuth();
    });
  }

  Future<void> _onSelect(int index) async {
    switch (_items[index]) {
      case 'NOUVELLE INSTALLATION (base vide)':
        await _newInstall();
      case 'CHARGER UNE SAUVEGARDE LOCALE / USB':
        await _restoreLocal();
      case 'CHARGER DEPUIS GOOGLE DRIVE (EN LIGNE)':
        await _restoreFromDrive();
      case 'CONFIGURER GOOGLE DRIVE (OAuth)':
        await _configureDrive();
      case 'QUITTER STORA':
        await AppExit.quit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'PREMIÈRE INSTALLATION',
      subtitle: 'Aucune base de données locale trouvée',
      helpLines: const [
        '↑↓ Entrée : choisir | Cette étape n\'apparaît que sans base locale',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
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
                onCancel: () {},
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
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    Text('Veuillez patienter...',
                        style: DosTheme.text(weight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Google Drive en ligne nécessite un Client OAuth\n'
                    '(Google Cloud Console → Application de bureau)\n'
                    'et l\'API Drive activée.',
                    style: DosTheme.dim(size: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OAuthConfigDialog extends StatefulWidget {
  const _OAuthConfigDialog();

  @override
  State<_OAuthConfigDialog> createState() => _OAuthConfigDialogState();
}

class _OAuthConfigDialogState extends State<_OAuthConfigDialog> {
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
                'Collez le Client ID et le Client Secret\n'
                'créés dans Google Cloud (type Bureau).',
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

class _DriveFilePickDialog extends StatefulWidget {
  const _DriveFilePickDialog({required this.files});

  final List<DriveBackupFile> files;

  @override
  State<_DriveFilePickDialog> createState() => _DriveFilePickDialogState();
}

class _DriveFilePickDialogState extends State<_DriveFilePickDialog> {
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
                Text('SAUVEGARDES GOOGLE DRIVE',
                    style: DosTheme.title(size: 18)),
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
                        child: Text(
                          widget.files[i].label,
                          style: DosTheme.text(weight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text('ENTRÉE: Charger | ECHAP: Annuler',
                    style: DosTheme.dim(size: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
