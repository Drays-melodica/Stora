import 'package:flutter/material.dart';

import '../../services/app_exit.dart';
import '../../services/auth_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../main_menu_screen.dart';

class SetupAdminScreen extends StatefulWidget {
  const SetupAdminScreen({super.key});

  @override
  State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(Map<String, String> values) async {
    final password = values['MOT DE PASSE'] ?? '';
    final confirm = values['CONFIRMER'] ?? '';

    if (password != confirm) {
      await DosDialog.error(
        context,
        title: 'Erreur',
        message: 'Les mots de passe ne correspondent pas.',
      );
      return;
    }

    try {
      await AuthService.instance.createAdmin(
        username: values['IDENTIFIANT']!,
        fullName: values['NOM COMPLET']!,
        password: password,
      );
      if (mounted) {
        await DosDialog.success(
          context,
          title: 'Administrateur créé',
          message:
              'Compte administrateur créé avec succès.\nBienvenue, ${AuthService.instance.currentAgentName}.',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainMenuScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        await DosDialog.error(context, title: 'Erreur', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'PREMIER LANCEMENT',
      subtitle: 'Création du compte administrateur STORA',
      captureKeyboard: false,
      helpLines: const [
        'Ce compte aura tous les droits (agents, paramètres, stock).',
        'F10: Créer | ECHAP: Quitter',
      ],
      child: DosBox(
        title: 'NOUVEL ADMINISTRATEUR',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aucun utilisateur détecté. Créez l\'administrateur principal.',
                style: DosTheme.text(),
              ),
              const SizedBox(height: 16),
              DosForm(
                submitLabel: 'CRÉER L\'ADMINISTRATEUR [F10]',
                onSubmit: _submit,
                onCancel: () async {
                  final quit = await DosDialog.confirm(
                    context,
                    title: 'Quitter STORA',
                    message: 'Voulez-vous vraiment quitter le logiciel ?',
                  );
                  if (quit == true) await AppExit.quit();
                },
                fields: [
                  DosFormField(
                    label: 'IDENTIFIANT',
                    controller: _usernameCtrl,
                    required: true,
                    maxLength: 30,
                  ),
                  DosFormField(
                    label: 'NOM COMPLET',
                    controller: _fullNameCtrl,
                    required: true,
                  ),
                  DosFormField(
                    label: 'MOT DE PASSE',
                    controller: _passwordCtrl,
                    required: true,
                    obscure: true,
                  ),
                  DosFormField(
                    label: 'CONFIRMER',
                    controller: _confirmCtrl,
                    required: true,
                    obscure: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
