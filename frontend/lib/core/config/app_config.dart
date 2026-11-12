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
  static bool useMockData = const bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// `true` : connexion et inscription simulées en mémoire (tests).
  /// `false` : le mot de passe est vérifié et le compte est écrit dans MySQL.
  static bool useApiAuth = const bool.fromEnvironment(
    'USE_API_AUTH',
    defaultValue: true,
  );

  /// `true` : le catalogue (restaurants, catégories, produits, favoris) vient
  /// de l'API même quand [useMockData] est vrai. Front office et back office
  /// partagent alors les mêmes données, les autres modules restent en mock.
  /// Les tests le passent à `false` (données mock, sans serveur).
  static bool useApiCatalogue = const bool.fromEnvironment(
    'USE_API_CATALOGUE',
    defaultValue: true,
  );

  /// Commandes et livraisons lues et écrites dans SQLite via l'API.
  static const bool useApiOrders = bool.fromEnvironment(
    'USE_API_ORDERS',
    defaultValue: true,
  );

  /// Avis, notifications et campagnes lus et écrits dans SQLite via l'API
  /// (sinon en mémoire, perdus à la fermeture de l'application).
  /// Les tests le passent à `false` (données mock, sans serveur).
  static bool useApiAvisNotifications = const bool.fromEnvironment(
    'USE_API_AVIS_NOTIFICATIONS',
    defaultValue: true,
  );

  /// Mode démonstration : identifiants pré-remplis et boutons « compte de
  /// démo ». Désactivé dans les builds de production (DEMO_MODE=false).
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  /// URL de base de l'API REST.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Connexion Google : identifiant client OAuth « Web » (audience de l'ID
  /// token vérifié par le serveur, dans GOOGLE_CLIENT_IDS du backend).
  /// Vide : le bouton Google est masqué en mode API.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '561939304792-4iaq4db1dh9mq59sdr967mgr272q3u8c.apps.googleusercontent.com',
  );

  /// Identifiant client OAuth « iOS » (facultatif sur Android).
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  /// Bouton Google affiché : démo en mémoire, ou API avec un identifiant.
  static bool get googleSignInEnabled =>
      !useApiAuth || googleServerClientId.isNotEmpty;

  /// Délai réseau simulé par les dépôts mock (tiré entre ces deux bornes).
  /// Les tests le passent à zéro.
  static Duration mockLatencyMin = const Duration(milliseconds: 300);
  static Duration mockLatencyMax = const Duration(milliseconds: 800);
}
