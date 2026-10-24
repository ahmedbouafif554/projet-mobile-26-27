/// Configuration globale de l'application.
///
/// Les valeurs peuvent être changées au lancement, sans toucher au code :
/// ```
/// flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://mon-api/v1
/// ```
class AppConfig {
  AppConfig._();

  /// `true` : les dépôts utilisent les données mock (aucun appel réseau).
  /// `false` : les dépôts appellent l'API REST avec Dio.
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// URL de base de l'API REST.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.superfaster.dev/v1',
  );

  /// Identifiant de l'utilisateur connecté (session simulée).
  static const String currentUserId = 'u-me';

  /// Latence simulée des dépôts mock (modifiable dans les tests).
  static Duration mockLatency = const Duration(milliseconds: 600);

  /// Délai des réactions simulées du « serveur » en mode mock
  /// (ex. : le restaurant répond à un avis). Modifiable dans les tests.
  static Duration mockServerDelay = const Duration(seconds: 6);
}
