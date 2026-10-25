import '../../shared/models/user.dart';

/// Chemins du front office. Toujours passer par ces constantes.
class FrontRoutes {
  FrontRoutes._();

  // Module 1 — parcours public
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';

  // Onglets du client
  static const explore = '/explore';
  static const search = '/search';
  static const cart = '/cart';
  static const orders = '/orders';
  static const profile = '/profile';

  // Module 2 — catalogue (dans les onglets Explorer et Recherche)
  static const restaurants = '/explore/restaurants';

  /// Fiche d'un restaurant ouverte dans l'onglet [tab] (Explorer par défaut).
  static String restaurant(String id, {String tab = explore}) =>
      '$tab/restaurant/$id';

  /// Avis d'un restaurant (sous sa fiche).
  static String restaurantReviews(String id, {String tab = explore}) =>
      '${restaurant(id, tab: tab)}/reviews';

  // Module 3 — commandes
  static const checkout = '/cart/checkout';
  static String orderConfirmed(String id) => '/order-confirmed/$id';
  static String order(String id) => '$orders/$id';
  static String orderTracking(String id) => '$orders/$id/track';
  static String writeReview(String id) => '$orders/$id/review';

  // Onglets du livreur (tout l'espace livreur est sous /courier)
  static const courierArea = '/courier';
  static const courierDashboard = '/courier/dashboard';
  static const courierDeliveries = '/courier/deliveries';
  static const courierEarnings = '/courier/earnings';
  static const courierMessages = '/courier/messages';
  static const courierProfile = '/courier/profile';

  // Module 4 — livraison
  static String courierDelivery(String id) => '$courierDeliveries/$id';
  static String courierChat(String id) => '$courierMessages/$id';

  // Module 1 — compte, partagé par les deux rôles (plein écran)
  static const accountArea = '/account';
  static const editProfile = '/account/edit';
  static const addresses = '/account/addresses';
  static const settings = '/account/settings';
  static const favorites = '/account/favorites';
  static const documents = '/account/documents';

  // Module 5 — communication (plein écran, client et livreur)
  static const myReviews = '/account/reviews';
  static const notifications = '/account/notifications';
  static const notificationSettings = '/account/notifications/settings';
  static const messages = '/account/messages';
  static String chat(String id) => '$messages/$id';

  /// Accessibles sans être connecté.
  static const publicPaths = {
    splash,
    onboarding,
    login,
    register,
    otp,
    forgotPassword,
  };

  /// Premier écran après la connexion.
  static String homeFor(UserRole role) =>
      role == UserRole.courier ? courierDashboard : explore;

  /// Onglet Profil du rôle.
  static String profileFor(UserRole role) =>
      role == UserRole.courier ? courierProfile : profile;

  /// Vérification du numéro après l'inscription.
  static String otpFor({required String phone, required String userId}) => Uri(
    path: otp,
    queryParameters: {'phone': phone, 'uid': userId},
  ).toString();
}
