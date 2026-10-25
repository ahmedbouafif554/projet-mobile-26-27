import 'dart:math';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'mock_catalog.dart';
import 'mock_users.dart';

/// 32 commandes réparties sur les 7 derniers jours (graphiques du dashboard),
/// générées de façon déterministe (toujours les mêmes à chaque lancement).
class MockOrders {
  MockOrders._();

  static final DateTime _now = DateTime.now();

  /// Livreurs des commandes en livraison / livrées (voir mock_delivery.dart).
  static const courierIds = ['c-1', 'c-2', 'c-3', 'c-4', 'c-5'];

  static const _clients = [
    'u-client-1',
    'u-client-2',
    'u-client-3',
    'u-client-4',
    'u-client-5',
    'u-client-6',
    'u-client-7',
    'u-client-8',
  ];

  /// Statuts des commandes les plus récentes (index 0 = la plus récente).
  static const _recentStatuses = [
    OrderStatus.preparing, // commande en cours d'Alex (suivi en temps réel)
    OrderStatus.delivering,
    OrderStatus.pending,
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.ready,
    OrderStatus.delivering,
    OrderStatus.ready,
  ];

  static final List<Order> orders = _generate();

  static List<Order> _generate() {
    final random = Random(7);
    final restaurants = MockCatalog.approvedRestaurants;
    final result = <Order>[];
    var minutesAgo = 6;

    for (var i = 0; i < 32; i++) {
      // Alex commande régulièrement (historique du front office).
      final userId = i % 6 == 0 ? 'u-client-1' : _clients[i % _clients.length];
      final user = MockUsers.byId(userId);
      final restaurant = restaurants[(i * 3 + 1) % restaurants.length];
      final products = MockCatalog.productsOf(
        restaurant.id,
      ).where((p) => p.isAvailable).toList();

      final status = i < _recentStatuses.length
          ? _recentStatuses[i]
          : i % 9 == 4
          ? OrderStatus.cancelled
          : i % 13 == 7
          ? OrderStatus.refunded
          : OrderStatus.delivered;

      final createdAt = _now.subtract(Duration(minutes: minutesAgo));
      // Les commandes en cours datent de la journée, l'historique s'étale
      // sur la semaine (graphique « ventes sur 7 jours »).
      minutesAgo += i < _recentStatuses.length
          ? 14 + random.nextInt(18)
          : 230 + random.nextInt(300);

      final items = [
        for (var k = 0; k < 1 + random.nextInt(3); k++)
          _item(products[(i + k * 2) % products.length], random, '$i-$k'),
      ];
      final hasCourier =
          status == OrderStatus.delivering || status == OrderStatus.delivered;

      result.add(
        Order(
          id: 'o-${i + 1}',
          reference: 'SF${1077 - i}',
          userId: userId,
          customerName: user.fullName,
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          items: items,
          deliveryAddress: MockUsers.defaultAddressOf(userId),
          deliveryFee: restaurant.deliveryFee,
          serviceFee: 0.99,
          discount: i % 7 == 3 ? 5 : 0,
          promoCode: i % 7 == 3 ? 'FAST5' : null,
          status: status,
          paymentMethod: PaymentMethod.values[i % PaymentMethod.values.length],
          paymentStatus: switch (status) {
            OrderStatus.refunded => PaymentStatus.refunded,
            OrderStatus.cancelled => PaymentStatus.refunded,
            _ when i % PaymentMethod.values.length == 2 =>
              PaymentStatus.pending,
            _ => PaymentStatus.paid,
          },
          // La commande n° 6 est la livraison en cours de Karim (livreur démo).
          courierId: !hasCourier
              ? null
              : i == 6
              ? 'c-1'
              : courierIds[i % courierIds.length],
          cancelReason: status == OrderStatus.cancelled
              ? 'Restaurant fermé plus tôt que prévu'
              : null,
          history: _history(status, createdAt),
          createdAt: createdAt,
        ),
      );
    }
    return result;
  }

  static CartItem _item(Product product, Random random, String key) {
    // Premier choix de chaque groupe obligatoire.
    final options = [
      for (final g in product.optionGroups)
        if (g.isRequired) g.options[random.nextInt(g.options.length)],
    ];
    return CartItem(
      id: 'oi-$key',
      product: product,
      quantity: 1 + random.nextInt(2),
      options: options,
    );
  }

  /// Étapes franchies jusqu'au statut actuel, espacées de quelques minutes.
  static List<OrderStatusEvent> _history(OrderStatus status, DateTime start) {
    const flow = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.delivering,
      OrderStatus.delivered,
    ];
    if (status == OrderStatus.cancelled) {
      return [
        OrderStatusEvent(status: OrderStatus.pending, at: start),
        OrderStatusEvent(
          status: OrderStatus.cancelled,
          at: start.add(const Duration(minutes: 4)),
          note: 'Restaurant fermé plus tôt que prévu',
        ),
      ];
    }
    final last = status == OrderStatus.refunded
        ? flow.length - 1
        : flow.indexOf(status);
    // 7 minutes entre deux étapes, resserrées pour les commandes récentes
    // (aucune étape dans le futur).
    final elapsed = DateTime.now().difference(start);
    final step = last == 0
        ? Duration.zero
        : Duration(
            seconds: (elapsed.inSeconds * 0.9 / last)
                .clamp(0, 7 * 60)
                .round(),
          );
    return [
      for (var k = 0; k <= last; k++)
        OrderStatusEvent(status: flow[k], at: start.add(step * k)),
      if (status == OrderStatus.refunded)
        OrderStatusEvent(
          status: OrderStatus.refunded,
          at: start.add(const Duration(hours: 2)),
          note: 'Article manquant',
        ),
    ];
  }
}
