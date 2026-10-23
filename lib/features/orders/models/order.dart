import 'cart_item.dart';

/// Étapes de vie d'une commande.
enum OrderStatus { confirmed, preparing, onTheWay, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.confirmed => 'Confirmée',
    OrderStatus.preparing => 'En préparation',
    OrderStatus.onTheWay => 'En route',
    OrderStatus.delivered => 'Livrée',
    OrderStatus.cancelled => 'Annulée',
  };

  bool get isActive =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  /// Étape suivante dans la simulation du suivi.
  OrderStatus get next => switch (this) {
    OrderStatus.confirmed => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.onTheWay,
    OrderStatus.onTheWay => OrderStatus.delivered,
    _ => this,
  };
}

/// Type de commande : repas/courses ou envoi de colis.
enum OrderType { food, parcel }

/// Commande passée (mock).
class Order {
  Order({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.address,
    required this.paymentLabel,
    required this.status,
    this.serviceFee = 0.99,
    this.discount = 0,
    this.restaurantId,
    this.type = OrderType.food,
    this.etaMinutes = 30,
    this.details,
  });

  final String id;
  final String title;
  final String imageUrl;
  final DateTime createdAt;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final String address;
  final String paymentLabel;
  final String? restaurantId;
  final OrderType type;
  final int etaMinutes;

  /// Description libre (utilisée pour les colis).
  final String? details;

  /// Seul champ modifiable : avance pendant le suivi simulé.
  OrderStatus status;

  double get total => subtotal + deliveryFee + serviceFee - discount;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Numéro affiché : « #SF1042 »
  String get displayNumber => '#$id';

  /// Résumé : « 2× Classic Cheeseburger, 1× Frites maison »
  String get summary => items.isEmpty
      ? (details ?? '')
      : items.map((i) => '${i.quantity}× ${i.product.name}').join(', ');
}
