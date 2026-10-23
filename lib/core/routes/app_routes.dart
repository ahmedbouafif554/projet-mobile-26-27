/// Chemins de toutes les routes de l'application.
/// Toujours passer par ces constantes/fonctions plutôt que des chaînes en dur.
class AppRoutes {
  AppRoutes._();

  // Authentification
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const otp = '/otp';
  static const forgotPassword = '/forgot-password';

  // Onglets de la barre de navigation
  static const home = '/home';
  static const search = '/search';
  static const orders = '/orders';
  static const profile = '/profile';

  // Catalogue
  static const restaurants = '/restaurants';
  static const restaurant = '/restaurant';
  static const product = '/product';
  static const favorites = '/favorites';

  // Commandes & livraison
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderConfirmation = '/order-confirmation';
  static const tracking = '/tracking';
  static const parcel = '/parcel';

  // Profil
  static const editProfile = '/edit-profile';
  static const addresses = '/addresses';
  static const paymentMethods = '/payment-methods';
  static const notificationSettings = '/notification-settings';
  static const language = '/language';
  static const notifications = '/notifications';

  // Administration
  static const admin = '/admin';

  // --- Constructeurs de chemins avec paramètres ---

  /// [hero] identifie la liste d'origine pour une animation Hero unique.
  static String restaurantDetail(String id, {String hero = 'list'}) =>
      '$restaurant/$id?hero=$hero';

  static String productDetail(String id, {String hero = 'menu'}) =>
      '$product/$id?hero=$hero';

  static String restaurantsWith({String? category, String? filter}) => Uri(
    path: restaurants,
    queryParameters: {
      if (category != null) 'category': category,
      if (filter != null) 'filter': filter,
    },
  ).toString();

  static String otpFor(String phone) =>
      Uri(path: otp, queryParameters: {'phone': phone}).toString();

  static String trackingOf(String orderId) => '$tracking/$orderId';

  static String confirmationOf(String orderId) => '$orderConfirmation/$orderId';
}

/// Tags Hero : une même image peut apparaître dans plusieurs listes
/// à l'écran, le préfixe garantit l'unicité du tag.
class HeroTags {
  HeroTags._();

  static String restaurant(String id, String origin) =>
      'restaurant-$origin-$id';
  static String product(String id, String origin) => 'product-$origin-$id';
}
