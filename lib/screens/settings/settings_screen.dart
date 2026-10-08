import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/dos_theme.dart';
import '../../widgets/dos_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _openBackup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'PARAMÈTRES SYSTÈME',
      subtitle: 'Configuration de l\'application',
      helpLines: const [
        'Société / Sauvegarde / À propos : barre menus du menu principal (F10)',
        'F3: Sauvegarde | ECHAP: Retour au menu',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f3:
            _openBackup();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'INFORMATIONS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line('Application', 'STORA'),
            _line('Version', '2.0.0'),
            _line('Mode affichage', 'Plein écran'),
            _line('Navigation', 'Clavier uniquement'),
            const SizedBox(height: 12),
            Text(
              'Menus système : barre en haut du menu principal\n'
              'Système │ Société │ Aide  (touche F10)',
              style: DosTheme.dim(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text('$label:', style: DosTheme.text())),
          Expanded(
              child: Text(value, style: DosTheme.text(weight: FontWeight.bold))),
        ],
      ),
    );
  }
}
