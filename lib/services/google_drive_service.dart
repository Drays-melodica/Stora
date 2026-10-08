import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/google_drive_oauth.dart';

class DriveBackupFile {
  DriveBackupFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;

  String get label {
    final when = modifiedTime != null
        ? '${modifiedTime!.day.toString().padLeft(2, '0')}/'
            '${modifiedTime!.month.toString().padLeft(2, '0')}/'
            '${modifiedTime!.year} '
            '${modifiedTime!.hour.toString().padLeft(2, '0')}:'
            '${modifiedTime!.minute.toString().padLeft(2, '0')}'
        : '?';
    return '$name  ($when)';
  }
}

/// Sauvegarde / restauration via l'API Google Drive (cloud, pas le dossier local).
class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  static const _folderName = 'STORA_Backups';
  static const _scopes = [drive.DriveApi.driveFileScope];

  static const _prefClientId = 'stora_gdrive_client_id';
  static const _prefClientSecret = 'stora_gdrive_client_secret';
  static const _prefCredentials = 'stora_gdrive_credentials_json';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<(String id, String secret)?> getConfiguredCredentials() async {
    final prefs = await _prefs;
    var id = prefs.getString(_prefClientId)?.trim() ?? '';
    var secret = prefs.getString(_prefClientSecret)?.trim() ?? '';
    if (id.isEmpty) id = GoogleDriveOAuthConfig.clientId.trim();
    if (secret.isEmpty) secret = GoogleDriveOAuthConfig.clientSecret.trim();
    if (id.isEmpty || secret.isEmpty) return null;
    return (id, secret);
  }

  Future<bool> get isConfigured async =>
      (await getConfiguredCredentials()) != null;

  Future<void> saveOAuthClient(String clientId, String clientSecret) async {
    final prefs = await _prefs;
    await prefs.setString(_prefClientId, clientId.trim());
    await prefs.setString(_prefClientSecret, clientSecret.trim());
  }

  Future<void> signOut() async {
    final prefs = await _prefs;
    await prefs.remove(_prefCredentials);
  }

  Future<AccessCredentials?> _loadStoredCredentials() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_prefCredentials);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AccessCredentials.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeCredentials(AccessCredentials creds) async {
    final prefs = await _prefs;
    await prefs.setString(_prefCredentials, jsonEncode(creds.toJson()));
  }

  Future<AutoRefreshingAuthClient> _authClient() async {
    final configured = await getConfiguredCredentials();
    if (configured == null) {
      throw Exception(
        'Google Drive non configuré.\n'
        'Indiquez le Client ID et le Client Secret OAuth\n'
        '(Google Cloud → Identifiants → Application de bureau).',
      );
    }

    final clientId = ClientId(configured.$1, configured.$2);
    final httpClient = http.Client();

    var credentials = await _loadStoredCredentials();
    if (credentials != null) {
      try {
        if (credentials.accessToken.expiry
            .isBefore(DateTime.now().toUtc().add(const Duration(minutes: 2)))) {
          if (credentials.refreshToken != null) {
            credentials = await refreshCredentials(
              clientId,
              credentials,
              httpClient,
            );
            await _storeCredentials(credentials);
          } else {
            credentials = null;
          }
        }
      } catch (_) {
        credentials = null;
      }
    }

    if (credentials == null) {
      credentials = await obtainAccessCredentialsViaUserConsent(
        clientId,
        _scopes,
        httpClient,
        (String url) async {
          final ok = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!ok) {
            throw Exception(
              'Impossible d\'ouvrir le navigateur pour Google.\n'
              'Ouvrez manuellement :\n$url',
            );
          }
        },
      );
      await _storeCredentials(credentials);
    }

    return autoRefreshingClient(clientId, credentials, httpClient);
  }

  Future<drive.DriveApi> _api() async {
    final client = await _authClient();
    return drive.DriveApi(client);
  }

  Future<String> _ensureBackupFolder(drive.DriveApi api) async {
    final listed = await api.files.list(
      q: "name = '$_folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    final existing = listed.files;
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      return existing.first.id!;
    }

    final created = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    if (created.id == null) {
      throw Exception('Impossible de créer le dossier $_folderName sur Drive.');
    }
    return created.id!;
  }

  /// Envoie un fichier .db vers Google Drive (dossier STORA_Backups).
  Future<String> uploadDatabaseBackup(String localDbPath) async {
    final file = File(localDbPath);
    if (!await file.exists()) {
      throw Exception('Fichier de base introuvable.');
    }

    final api = await _api();
    final folderId = await _ensureBackupFolder(api);
    final name =
        'stora_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.db';
    final length = await file.length();

    final created = await api.files.create(
      drive.File()
        ..name = name
        ..parents = [folderId],
      uploadMedia: drive.Media(file.openRead(), length),
    );

    return created.name ?? name;
  }

  Future<List<DriveBackupFile>> listBackups() async {
    final api = await _api();
    final folderId = await _ensureBackupFolder(api);
    final listed = await api.files.list(
      q: "'$folderId' in parents and trashed = false and name contains 'stora_backup'",
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      pageSize: 50,
      $fields: 'files(id, name, modifiedTime, size)',
    );

    final files = listed.files ?? [];
    return files
        .where((f) => f.id != null && f.name != null)
        .map(
          (f) => DriveBackupFile(
            id: f.id!,
            name: f.name!,
            modifiedTime: f.modifiedTime,
            sizeBytes: int.tryParse(f.size ?? ''),
          ),
        )
        .toList();
  }

  /// Télécharge une sauvegarde Drive vers un fichier temporaire local.
  Future<String> downloadBackupToTemp(String fileId, String fileName) async {
    final api = await _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dir = await getTemporaryDirectory();
    final dest = File(p.join(dir.path, 'stora_restore_$fileName'));
    final sink = dest.openWrite();
    await media.stream.pipe(sink);
    await sink.close();
    return dest.path;
  }
}
