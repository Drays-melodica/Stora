import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../database/database_helper.dart';

/// Sauvegarde / restauration de la base SQLite (dossier, USB, Google Drive local).
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  final _db = DatabaseHelper.instance;
  final _stamp = DateFormat('yyyyMMdd_HHmmss');

  Future<String> get databasePath => _db.getDatabasePath();

  Future<void> _restoreFocus() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(true);
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _checkpoint() async {
    final db = await _db.database;
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
  }

  /// Expose pour upload Drive (flush WAL avant copie).
  Future<void> checkpointForUpload() => _checkpoint();

  String _backupFileName() => 'stora_backup_${_stamp.format(DateTime.now())}.db';

  Future<String> backupToDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final backupRoot = Directory(p.join(directoryPath, 'STORA_Backups'));
    await backupRoot.create(recursive: true);

    await _checkpoint();
    final src = await databasePath;
    final srcFile = File(src);
    if (!await srcFile.exists()) {
      throw Exception('Fichier de base introuvable.');
    }

    final destPath = p.join(backupRoot.path, _backupFileName());
    await srcFile.copy(destPath);
    return destPath;
  }

  Future<String?> pickFolder() async {
    try {
      if (Platform.isWindows) {
        final path = await _pickFolderWindows();
        if (path != null) return path;
      }
      return null;
    } finally {
      await _restoreFocus();
    }
  }

  Future<String?> pickBackupFile() async {
    try {
      if (Platform.isWindows) {
        return await _pickBackupFileWindows();
      }
      return null;
    } finally {
      await _restoreFocus();
    }
  }

  Future<String?> _pickFolderWindows() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.Application]::EnableVisualStyles()
$owner = New-Object System.Windows.Forms.Form
$owner.TopMost = $true
$owner.ShowInTaskbar = $false
$owner.FormBorderStyle = 'None'
$owner.Opacity = 0
$owner.Size = New-Object System.Drawing.Size(1, 1)
$owner.StartPosition = 'Manual'
$owner.Location = New-Object System.Drawing.Point(-10000, -10000)
$owner.Show()
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = 'Choisir le dossier de sauvegarde STORA'
$dialog.ShowNewFolderButton = $true
try {
  $result = $dialog.ShowDialog($owner)
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write($dialog.SelectedPath)
  }
} finally {
  $owner.Close()
  $owner.Dispose()
}
''';
    return _runPowerShell(script);
  }

  Future<String?> _pickBackupFileWindows() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.Application]::EnableVisualStyles()
$owner = New-Object System.Windows.Forms.Form
$owner.TopMost = $true
$owner.ShowInTaskbar = $false
$owner.FormBorderStyle = 'None'
$owner.Opacity = 0
$owner.Size = New-Object System.Drawing.Size(1, 1)
$owner.StartPosition = 'Manual'
$owner.Location = New-Object System.Drawing.Point(-10000, -10000)
$owner.Show()
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Restaurer une sauvegarde STORA'
$dialog.Filter = 'Base STORA|*.db|Tous|*.*'
$dialog.Multiselect = $false
$dialog.CheckFileExists = $true
try {
  $result = $dialog.ShowDialog($owner)
  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write($dialog.FileName)
  }
} finally {
  $owner.Close()
  $owner.Dispose()
}
''';
    return _runPowerShell(script);
  }

  Future<String?> _runPowerShell(String script) async {
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final path = (result.stdout as String).trim();
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  /// Lecteurs amovibles (USB, etc.).
  Future<List<String>> listRemovableDrives() async {
    if (!Platform.isWindows) return [];
    const script = r'''
Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -and $_.Size -gt 0 } | ForEach-Object { $_.DeviceID }
''';
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );
      if (result.exitCode != 0) return [];
      return (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.endsWith('\\') ? e : '$e\\')
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Dossiers Google Drive Desktop / Drive FS détectés localement.
  Future<List<String>> findGoogleDriveFolders() async {
    final found = <String>{};
    final home = Platform.environment['USERPROFILE'] ?? '';
    final candidates = <String>[
      if (home.isNotEmpty) ...[
        p.join(home, 'Google Drive'),
        p.join(home, 'GoogleDrive'),
        p.join(home, 'Mon Drive'),
        p.join(home, 'My Drive'),
      ],
      r'G:\My Drive',
      r'G:\Mon Drive',
    ];

    for (final c in candidates) {
      if (await Directory(c).exists()) found.add(c);
    }

    // Drive for desktop : souvent un lecteur virtuel G:
    for (final letter in ['G', 'H', 'I']) {
      final myDrive = '$letter:\\My Drive';
      final monDrive = '$letter:\\Mon Drive';
      if (await Directory(myDrive).exists()) found.add(myDrive);
      if (await Directory(monDrive).exists()) found.add(monDrive);
    }

    return found.toList();
  }

  Future<void> restoreFromFile(String backupPath) async {
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw Exception('Fichier de sauvegarde introuvable.');
    }
    final size = await backup.length();
    if (size < 100) {
      throw Exception('Fichier de sauvegarde invalide ou vide.');
    }

    final dest = await databasePath;
    await _db.closeDatabase();

    // Copier aussi les sidecars WAL/SHM s'ils existent (sinon les supprimer)
    final wal = File('$dest-wal');
    final shm = File('$dest-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();

    await backup.copy(dest);

    // Rouvrir
    await _db.database;
  }
}
