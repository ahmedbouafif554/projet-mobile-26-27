/// Chemins de toutes les routes de l'application.
/// Toujours passer par ces constantes/fonctions plutôt que des chaînes en dur.
///
/// Chaque écran vit sous la route de son module (voir modules_config.dart) :
/// `/auth`, `/explore`, `/orders`, `/delivery` et `/communication`.
/// L'écran principal d'un module est servi sur la route du module.
class AppRoutes {
  AppRoutes._();

  // Module 1 : authentification et utilisateurs
  static const splash = '/auth/splash';
  static const onboarding = '/auth/onboarding';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const otp = '/auth/otp';
  static const forgotPassword = '/auth/forgot-password';
  static const profile = '/auth';
  static const editProfile = '/auth/edit-profile';
  static const addresses = '/auth/addresses';
  static const language = '/auth/language';
  static const admin = '/auth/admin-dashboard';

  // Module 2 : restaurants et catalogue
  static const home = '/explore';
  static const search = '/explore/search';
  static const restaurants = '/explore/restaurants';
  static const restaurant = '/explore/restaurant';
  static const product = '/explore/product';
  static const favorites = '/explore/favorites';

  // Module 3 : panier et commandes
  static const cart = '/orders/cart';
  static const checkout = '/orders/checkout';
  static const paymentMethods = '/orders/payment';
  static const orderConfirmation = '/orders/confirmation';
  static const orders = '/orders';
  static const tracking = '/orders/tracking';

  // Module 4 : livraison
  static const parcel = '/delivery';

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
