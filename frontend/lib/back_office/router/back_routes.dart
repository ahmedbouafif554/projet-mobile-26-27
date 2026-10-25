/// Chemins du back office (Espace Pro). Toujours passer par ces constantes.
class BackRoutes {
  BackRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const account = '/account';

  // Module 1 — utilisateurs
  static const users = '/users';
  static String user(String id) => '$users/$id';

  // Module 2 — catalogue
  static const restaurants = '/restaurants';
  static String restaurant(String id) => '$restaurants/$id';
  static const categories = '/categories';
  static const products = '/products';
  static const myRestaurant = '/my-restaurant';

  // Module 3 — commandes
  static const orders = '/orders';
  static String order(String id) => '$orders/$id';
  static const kitchen = '/kitchen';

  // Module 4 — livraison
  static const couriers = '/couriers';
  static String courier(String id) => '$couriers/$id';
  static const deliveries = '/deliveries';
  static const map = '/map';

  // Module 5 — communication
  static const reviews = '/reviews';
  static const campaigns = '/campaigns';
  static const chats = '/chats';
  /// Conversation ouverte dans la même page que la liste (paramètre `id`).
  static String chat(String id) => '$chats?id=$id';
}
