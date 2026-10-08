import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../theme/dos_theme.dart';
import '../theme/stora_brand.dart';
import '../widgets/dos_screen.dart';
import 'auth/first_run_database_screen.dart';
import 'auth/login_screen.dart';
import 'auth/setup_admin_screen.dart';

/// Séquence de démarrage style BIOS.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final List<String> _lines = [];
  int _lineIndex = 0;
  Timer? _timer;

  static const _bootLines = [
    'STORA STOCK MANAGEMENT SYSTEM v2.0',
    'Copyright (C) 2026 IDRISS EL-HIMER',
    '',
    StoraBrand.licenseTitle,
    ...StoraBrand.licenseLines,
    '',
    'Initialisation du système...',
    'Vérification mémoire.................. OK',
    'Chargement base de données locale..... ...',
    'Module authentification............... OK',
    'Configuration clavier................. OK',
    'Mode plein écran...................... OK',
    '',
    'Appuyez sur une touche pour continuer...',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_lineIndex < _bootLines.length) {
        setState(() {
          _lines.add(_bootLines[_lineIndex]);
          _lineIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    final exists = await DatabaseHelper.instance.databaseFileExists();
    if (!mounted) return;

    if (!exists) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FirstRunDatabaseScreen()),
      );
      return;
    }

    await DatabaseHelper.instance.database;
    final hasAdmin = await AuthService.instance.hasAdmin();
    if (!mounted) return;

    final next =
        hasAdmin ? const LoginScreen() : const SetupAdminScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && _lineIndex >= _bootLines.length) {
          _continue();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DosScreen(
        title: 'SYSTEM BOOT',
        captureKeyboard: false,
        helpLines: const ['Appuyez sur une touche pour continuer'],
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STORA', style: DosTheme.title(size: 32)),
              const SizedBox(height: 24),
              ..._lines.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(l, style: DosTheme.text()),
                  )),
              if (_lineIndex >= _bootLines.length) const _BlinkingCursor(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _visible ? '_' : ' ',
      style: DosTheme.text(size: 18),
    );
  }
}
