import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart' show dosMatchesQuery;
import '../../widgets/dos_searchable_table.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AppUser> _all = [];
  List<AppUser> _users = [];
  int _selectedIndex = 0;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    if (!mounted) return;
    setState(() {
      _all = users;
      _applyFilter(_searchCtrl.text);
    });
  }

  void _applyFilter(String query) {
    _users = _all
        .where((u) => dosMatchesQuery(query, [
              '${u.id}',
              u.username,
              u.fullName,
              u.roleLabel,
              u.active ? 'ACTIF' : 'INACTIF',
            ]))
        .toList();
    if (_users.isNotEmpty) {
      _selectedIndex = _selectedIndex.clamp(0, _users.length - 1);
    } else {
      _selectedIndex = 0;
    }
  }

  Future<void> _addAgent() async {
    final usernameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'NOUVEL AGENT',
          captureKeyboard: false,
          helpLines: const ['F10: Créer | ECHAP: Annuler'],
          child: DosBox(
            title: 'COMPTE AGENT',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  await AuthService.instance.createAgent(
                    username: values['IDENTIFIANT']!,
                    fullName: values['NOM COMPLET']!,
                    password: values['MOT DE PASSE']!,
                  );
                  if (ctx.mounted) {
                    await DosDialog.success(
                      ctx,
                      title: 'Agent créé',
                      message: 'Agent ${values['NOM COMPLET']} ajouté.',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    await DosDialog.error(
                        ctx, title: 'Erreur', message: e.toString());
                  }
                }
              },
              fields: [
                DosFormField(
                  label: 'IDENTIFIANT',
                  controller: usernameCtrl,
                  required: true,
                ),
                DosFormField(
                  label: 'NOM COMPLET',
                  controller: fullNameCtrl,
                  required: true,
                ),
                DosFormField(
                  label: 'MOT DE PASSE',
                  controller: passwordCtrl,
                  required: true,
                  obscure: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    usernameCtrl.dispose();
    fullNameCtrl.dispose();
    passwordCtrl.dispose();
    await _load();
  }

  Future<void> _toggleActive() async {
    if (_users.isEmpty) return;
    final user = _users[_selectedIndex];
    final me = AuthService.instance.currentUser;

    if (user.isAdmin) {
      await DosDialog.info(
        context,
        title: 'Administrateur',
        message:
            'Le compte administrateur ne peut pas être désactivé depuis cet écran.',
      );
      return;
    }

    if (me?.id == user.id) {
      await DosDialog.error(
        context,
        title: 'Impossible',
        message: 'Vous ne pouvez pas désactiver votre propre compte.',
      );
      return;
    }

    final action = user.active ? 'désactiver' : 'réactiver';
    final confirm = await DosDialog.confirm(
      context,
      title: 'Confirmation',
      message: 'Voulez-vous $action l\'agent ${user.fullName} ?',
    );
    if (confirm == true) {
      await DatabaseHelper.instance.setUserActive(user.id!, !user.active);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentCount = _all.where((u) => u.role == UserRole.agent).length;

    return DosScreen(
      title: 'GESTION DES AGENTS',
      subtitle:
          '${_users.length}/${_all.length} compte(s) — $agentCount agent(s)',
      helpLines: const [
        'RECH> : taper | ↓ : tableau | ↑ ligne 1 : recherche',
        'F2: Nouvel agent | F3: Activer/Désactiver | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _addAgent();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            _toggleActive();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'LISTE DES UTILISATEURS',
        child: DosSearchableTable(
          searchController: _searchCtrl,
          searchHint: 'Identifiant, nom, rôle…',
          onSearchChanged: (q) => setState(() => _applyFilter(q)),
          headers: const ['ID', 'IDENTIFIANT', 'NOM', 'RÔLE', 'STATUT'],
          emptyMessage:
              'Aucun compte. F2 pour créer un agent (l\'admin apparaît ici aussi).',
          rows: _users
              .map((a) => [
                    '${a.id}',
                    a.username,
                    a.fullName,
                    a.roleLabel,
                    a.active ? 'ACTIF' : 'INACTIF',
                  ])
              .toList(),
          onSelectionChanged: (i) => setState(() => _selectedIndex = i),
          onSelect: (_) => _toggleActive(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
