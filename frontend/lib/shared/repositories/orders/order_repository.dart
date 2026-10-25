import '../../models/order.dart';
import '../base/crud_repository.dart';

/// Commandes (Module 3). [getAll] les renvoie de la plus récente à la plus
/// ancienne.
abstract interface class OrderRepository implements CrudRepository<Order> {
  Future<List<Order>> forUser(String userId);

  Future<List<Order>> forRestaurant(String restaurantId);

  /// Nouveau statut, ajouté à l'historique de la commande.
  Future<Order> updateStatus(String id, OrderStatus status, {String? note});

  Future<Order> cancel(String id, String reason);

  Future<Order> refund(String id);
}
