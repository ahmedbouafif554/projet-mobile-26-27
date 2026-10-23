import '../../catalog/data/catalog_mock_data.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/promo_code.dart';

/// Fausses données des commandes : codes promo et historique.
class OrdersMockData {
  OrdersMockData._();

  /// Frais de service fixes appliqués à chaque commande.
  static const double serviceFee = 0.99;

  static const List<PromoCode> promoCodes = [
    PromoCode(
      code: 'BIENVENUE30',
      description: '-30 % sur votre commande',
      type: PromoType.percent,
      value: 30,
    ),
    PromoCode(
      code: 'FAST5',
      description: '5 € offerts',
      type: PromoType.fixed,
      value: 5,
    ),
    PromoCode(
      code: 'LIVRAISON',
      description: 'Livraison offerte',
      type: PromoType.freeDelivery,
    ),
  ];

  static PromoCode? findPromo(String code) {
    final normalized = code.trim().toUpperCase();
    for (final promo in promoCodes) {
      if (promo.code == normalized) return promo;
    }
    return null;
  }

  /// Historique initial : une commande en cours et plusieurs passées.
  static List<Order> initialOrders() {
    final now = DateTime.now();
    return [
      _order(
        'SF1046',
        'r5',
        now.subtract(const Duration(minutes: 8)),
        OrderStatus.preparing,
        [_item('r5-tonkotsu', quantity: 2, sizeIndex: 1), _item('r5-gyoza')],
      ),
      _order(
        'SF1045',
        'r3',
        now.subtract(const Duration(days: 2, hours: 3)),
        OrderStatus.delivered,
        [_item('r3-sakura'), _item('r3-gyoza', quantity: 2)],
      ),
      _order(
        'SF1039',
        'r1',
        now.subtract(const Duration(days: 6, hours: 1)),
        OrderStatus.delivered,
        [
          _item('r1-classic', quantity: 2, sizeIndex: 1),
          _item('r1-fries', quantity: 2),
          _item('r1-lemonade'),
        ],
      ),
      _order(
        'SF1031',
        'r2',
        now.subtract(const Duration(days: 12)),
        OrderStatus.cancelled,
        [_item('r2-margherita'), _item('r2-tiramisu')],
      ),
      _order(
        'SF1024',
        'r4',
        now.subtract(const Duration(days: 20, hours: 5)),
        OrderStatus.delivered,
        [_item('r4-poke'), _item('r4-smoothie')],
      ),
    ];
  }

  static CartItem _item(String productId, {int quantity = 1, int? sizeIndex}) {
    final product = CatalogMockData.productById(productId);
    final sizeGroup = product.optionGroups.where((g) => g.id == 'size');
    return CartItem(
      product: product,
      quantity: quantity,
      size: sizeGroup.isEmpty ? null : sizeGroup.first.options[sizeIndex ?? 0],
    );
  }

  static Order _order(
    String id,
    String restaurantId,
    DateTime date,
    OrderStatus status,
    List<CartItem> items,
  ) {
    final restaurant = CatalogMockData.restaurantById(restaurantId);
    return Order(
      id: id,
      title: restaurant.name,
      imageUrl: restaurant.imageUrl,
      restaurantId: restaurantId,
      createdAt: date,
      items: items,
      subtotal: items.fold(0, (sum, i) => sum + i.totalPrice),
      deliveryFee: restaurant.deliveryFee,
      serviceFee: serviceFee,
      address: '12 rue de la Paix, 75002 Paris',
      paymentLabel: 'Visa •••• 4242',
      status: status,
      etaMinutes: restaurant.deliveryMinutes,
    );
  }
}
