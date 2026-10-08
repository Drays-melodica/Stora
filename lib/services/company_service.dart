import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../database/database_helper.dart';
import '../models/company_profile.dart';

class CompanyService {
  CompanyService._();
  static final CompanyService instance = CompanyService._();

  final _db = DatabaseHelper.instance;

  Future<CompanyProfile> getProfile() => _db.getCompanyProfile();

  Future<void> saveProfile(CompanyProfile profile) =>
      _db.saveCompanyProfile(profile);

  Future<String> getLogoStorageDir() async {
    final dir = await getApplicationSupportDirectory();
    final logoDir = p.join(dir.path, 'stora', 'assets');
    await Directory(logoDir).create(recursive: true);
    return logoDir;
  }

  /// Sélectionne un fichier image sans quitter le plein écran
  /// (éviter setFullScreen(false) qui casse la fenêtre frameless).
  Future<String?> _pickImagePath() async {
    if (Platform.isWindows) {
      final path = await _pickImagePathWindows();
      if (path != null) return path;
      // Si PowerShell échoue, essayer file_picker sans toucher au plein écran.
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'],
      allowMultiple: false,
      dialogTitle: 'Sélectionner le logo de la société',
      lockParentWindow: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  /// OpenFileDialog via PowerShell — processus séparé, STORA reste en plein écran.
  Future<String?> _pickImagePathWindows() async {
    // Owner TopMost pour que le dialogue apparaisse AU-DESSUS du plein écran.
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
$dialog.Title = 'Logo societe'
$dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.webp|Tous|*.*'
$dialog.Multiselect = $false
$dialog.CheckFileExists = $true
$dialog.RestoreDirectory = $true
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
      if (path.isEmpty) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreFullscreenFocus() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(true);
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<CompanyProfile?> pickAndSetLogo() async {
    String? sourcePath;
    try {
      sourcePath = await _pickImagePath();
    } finally {
      await _restoreFullscreenFocus();
    }

    if (sourcePath == null || sourcePath.isEmpty) return null;

    final ext = p.extension(sourcePath).toLowerCase();
    if (!['.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'].contains(ext)) {
      throw Exception('Format non supporté. Utilisez PNG, JPG ou BMP.');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Fichier logo introuvable.');
    }

    final logoDir = await getLogoStorageDir();
    final destPath = p.join(
      logoDir,
      'company_logo_${DateTime.now().millisecondsSinceEpoch}$ext',
    );

    try {
      final dir = Directory(logoDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File &&
              p.basename(entity.path).startsWith('company_logo')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}

    await source.copy(destPath);

    final profile = await getProfile();
    final updated = profile.copyWith(
      logoPath: destPath,
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }

  Future<CompanyProfile> removeLogo() async {
    final profile = await getProfile();
    if (profile.logoPath != null) {
      final file = File(profile.logoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final updated =
        profile.copyWith(clearLogo: true, updatedAt: DateTime.now());
    await saveProfile(updated);
    return updated;
  }
}
