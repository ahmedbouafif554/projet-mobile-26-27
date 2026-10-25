/// Configuration globale, commune au front office et au back office.
///
/// Les valeurs peuvent être changées au lancement, sans toucher au code :
/// ```
/// flutter run -t lib/main_front.dart --dart-define=USE_MOCK=false \
///   --dart-define=API_BASE_URL=https://mon-api/v1
/// ```
class AppConfig {
  AppConfig._();

  /// `true` : les dépôts utilisent les données mock en mémoire.
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

  /// Délai réseau simulé par les dépôts mock (tiré entre ces deux bornes).
  /// Les tests le passent à zéro.
  static Duration mockLatencyMin = const Duration(milliseconds: 300);
  static Duration mockLatencyMax = const Duration(milliseconds: 800);
}
