import 'package:flutter/foundation.dart';

import '../../../catalog/data/catalog_mock_data.dart';
import '../../data/orders_mock_data.dart';
import '../../models/order.dart';
import 'cart_controller.dart';

/// Liste des commandes de l'utilisateur (historique + en cours).
class OrdersController extends ChangeNotifier {
  OrdersController._() : _orders = OrdersMockData.initialOrders();
  static final OrdersController instance = OrdersController._();

  final List<Order> _orders;
  int _nextNumber = 1047;

  List<Order> get activeOrders =>
      _orders.where((o) => o.status.isActive).toList();

  List<Order> get pastOrders =>
      _orders.where((o) => !o.status.isActive).toList();

  bool get hasActiveOrder => _orders.any((o) => o.status.isActive);

  Order? byId(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Transforme le panier en commande, puis vide le panier.
  Order placeOrder({
    required CartController cart,
    required String address,
    required String paymentLabel,
  }) {
    final restaurant = CatalogMockData.restaurantById(
      cart.items.first.product.restaurantId,
    );
    final order = Order(
      id: 'SF${_nextNumber++}',
      title: restaurant.name,
      imageUrl: restaurant.imageUrl,
      restaurantId: restaurant.id,
      createdAt: DateTime.now(),
      items: cart.items,
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      serviceFee: cart.serviceFee,
      discount: cart.discount,
      address: address,
      paymentLabel: paymentLabel,
      status: OrderStatus.confirmed,
      etaMinutes: restaurant.deliveryMinutes,
    );
    _orders.insert(0, order);
    cart.clear();
    notifyListeners();
    return order;
  }

  /// Crée une commande d'envoi de colis.
  Order placeParcelOrder({
    required String sizeLabel,
    required String pickup,
    required String dropoff,
    required double price,
    required String imageUrl,
  }) {
    final order = Order(
      id: 'SF${_nextNumber++}',
      title: 'Colis express • $sizeLabel',
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      items: const [],
      subtotal: price,
      deliveryFee: 0,
      serviceFee: 0,
      address: dropoff,
      paymentLabel: 'Visa •••• 4242',
      status: OrderStatus.confirmed,
      type: OrderType.parcel,
      etaMinutes: 40,
      details: '$pickup → $dropoff',
    );
    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  void updateStatus(String id, OrderStatus status) {
    final order = byId(id);
    if (order == null || order.status == status) return;
    order.status = status;
    notifyListeners();
  }

  /// Remet tous les articles d'une ancienne commande dans le panier.
  void reorder(Order order, CartController cart) {
    for (final item in order.items) {
      cart.add(item);
    }
  }
}
