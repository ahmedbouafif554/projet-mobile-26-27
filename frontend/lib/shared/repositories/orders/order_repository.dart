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

  /// Crée un PaymentIntent Stripe pour une commande.
  Future<Map<String, dynamic>> createPaymentIntent(String orderId);

  /// Confirme le paiement Stripe d'une commande.
  Future<Map<String, dynamic>> confirmPayment(
    String orderId, {
    String? paymentIntentId,
  });

  // ─── Cadeaux ───────────────────────────────────────────────────────────────

  /// Ajoute un cadeau à une commande.
  Future<Map<String, dynamic>> addGift(
    String orderId,
    Map<String, dynamic> giftData,
  );

  /// Récupère le cadeau d'une commande.
  Future<Map<String, dynamic>> getGift(String orderId);

  /// Révèle un cadeau via son token QR.
  Future<Map<String, dynamic>> revealGift(String qrToken);

  // ─── Pourboires ────────────────────────────────────────────────────────────

  /// Ajoute un pourboire pour une commande.
  Future<Map<String, dynamic>> addTip(
    String orderId,
    Map<String, dynamic> tipData,
  );

  /// Récupère les pourboires d'une commande.
  Future<Map<String, dynamic>> getTip(String orderId);

  /// Historique des pourboires d'un livreur.
  Future<Map<String, dynamic>> getCourierTips(String courierId);
}
