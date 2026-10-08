/// Identifiants OAuth Google Drive (type « Application de bureau »).
///
/// Créez-les sur https://console.cloud.google.com/apis/credentials
/// Activez l'API Google Drive, puis créez un client OAuth Desktop.
///
/// Vous pouvez aussi les saisir dans STORA (écran sauvegarde) — ils seront
/// mémorisés localement. Les valeurs ici servent de défauts optionnels.
class GoogleDriveOAuthConfig {
  GoogleDriveOAuthConfig._();

  /// Client ID (…apps.googleusercontent.com)
  static const String clientId = String.fromEnvironment(
    'STORA_GDRIVE_CLIENT_ID',
    defaultValue: '',
  );

  /// Client Secret (applications desktop — considéré public côté client)
  static const String clientSecret = String.fromEnvironment(
    'STORA_GDRIVE_CLIENT_SECRET',
    defaultValue: '',
  );
}
