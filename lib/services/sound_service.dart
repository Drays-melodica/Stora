import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

/// Bips style DOS / BIOS (Windows Beep, sinon SystemSound).
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static int Function(int, int)? _winBeep;

  static void _ensureWinBeep() {
    if (_winBeep != null || !Platform.isWindows) return;
    try {
      final k32 = DynamicLibrary.open('kernel32.dll');
      _winBeep = k32.lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('Beep');
    } catch (_) {
      _winBeep = null;
    }
  }

  static void _tone(int freqHz, int durationMs) {
    _ensureWinBeep();
    final beep = _winBeep;
    if (beep != null) {
      try {
        beep(freqHz, durationMs);
        return;
      } catch (_) {}
    }
    SystemSound.play(SystemSoundType.alert);
  }

  /// Bip court de confirmation (ajout / enregistrement réussi).
  void beepOk() => _tone(880, 90);

  /// Double bip léger (création importante).
  void beepSuccess() {
    _tone(880, 80);
    _tone(1175, 100);
  }
}
