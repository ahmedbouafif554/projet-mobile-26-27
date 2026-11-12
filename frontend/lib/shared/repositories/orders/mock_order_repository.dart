import '../../models/order.dart';
import '../base/mock_crud_repository.dart';
import 'order_repository.dart';

class MockOrderRepository extends MockCrudRepository<Order>
    implements OrderRepository {
  MockOrderRepository(super.seed) : super(idPrefix: 'o');

  @override
  String idOf(Order item) => item.id;

  /// Attribue l'identifiant et le numéro suivant (« SF1078 »).
  @override
  Order withId(Order item, String id) {
    final numbers = [
      for (final o in items) int.tryParse(o.reference.substring(2)) ?? 0,
    ];
    final next = numbers.isEmpty
        ? 1001
        : numbers.reduce((a, b) => a > b ? a : b) + 1;
    return item.copyWith(
      id: id,
      reference: item.reference.isEmpty ? 'SF$next' : item.reference,
    );
  }

  @override
  Future<List<Order>> getAll() async =>
      (await super.getAll())
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Order>> forUser(String userId) async =>
      (await where((o) => o.userId == userId))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Order>> forRestaurant(String restaurantId) async =>
      (await where((o) => o.restaurantId == restaurantId))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Order> updateStatus(String id, OrderStatus status, {String? note}) =>
      mutate(id, (o) => o.withStatus(status, note: note));

  @override
  Future<Order> cancel(String id, String reason) => mutate(
    id,
    (o) => o
        .withStatus(OrderStatus.cancelled, note: reason)
        .copyWith(cancelReason: reason),
  );

  @override
  Future<Order> refund(String id) => mutate(
    id,
    (o) => o
        .withStatus(OrderStatus.refunded)
        .copyWith(paymentStatus: PaymentStatus.refunded),
  );

  @override
  Future<Map<String, dynamic>> createPaymentIntent(String orderId) async => {
    'orderId': orderId,
    'clientSecret': 'pi_demo_mock_secret',
    'paymentIntentId': 'pi_demo_mock',
  };

  @override
  Future<Map<String, dynamic>> confirmPayment(
    String orderId, {
    String? paymentIntentId,
  }) async => {
    'orderId': orderId,
    'paymentStatus': 'paid',
    'status': 'succeeded',
  };

  final Map<String, Map<String, dynamic>> _mockGifts = {};
  final Map<String, List<Map<String, dynamic>>> _mockTips = {};

  @override
  Future<Map<String, dynamic>> addGift(
    String orderId,
    Map<String, dynamic> giftData,
  ) async {
    final gift = {
      'id': 'gift_$orderId',
      'orderId': orderId,
      'recipientName': giftData['recipientName'] ?? 'Destinataire',
      'recipientPhone': giftData['recipientPhone'],
      'recipientEmail': giftData['recipientEmail'],
      'senderName': giftData['isAnonymous'] == true ? null : (giftData['senderName'] ?? 'Un ami'),
      'isAnonymous': giftData['isAnonymous'] ?? false,
      'message': giftData['message'],
      'giftCardDesign': giftData['giftCardDesign'] ?? 'festive',
      'scheduledAt': giftData['scheduledAt'],
      'qrCode': 'qr_mock_$orderId',
      'revealed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _mockGifts[orderId] = gift;
    return gift;
  }

  @override
  Future<Map<String, dynamic>> getGift(String orderId) async {
    if (_mockGifts.containsKey(orderId)) {
      return _mockGifts[orderId]!;
    }
    return {
      'id': 'gift_$orderId',
      'orderId': orderId,
      'recipientName': 'Ami Gourmand',
      'isAnonymous': false,
      'senderName': 'Client SuperFaster',
      'message': 'Bon appétit et joyeuse dégustation !',
      'giftCardDesign': 'festive',
      'qrCode': 'qr_mock_$orderId',
      'revealed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> revealGift(String qrToken) async {
    return {
      'gift': {
        'id': 'gift_revealed',
        'orderId': 'order_revealed',
        'recipientName': 'Destinataire',
        'isAnonymous': false,
        'senderName': 'Un proche bienveillant',
        'message': 'Surprise gourmande ! Savoure ce bon repas.',
        'giftCardDesign': 'festive',
        'revealed': true,
      },
      'order': {
        'id': 'order_revealed',
        'reference': 'SF-CADEAU-99',
        'restaurantName': 'Le Gourmet Express',
        'status': 'delivering',
        'createdAt': DateTime.now().toIso8601String(),
      },
      'items': [
        {'name': 'Menu Surprise Deluxe', 'quantity': 1, 'options': ['Sauce Maison', 'Frites croustillantes']},
        {'name': 'Boisson Pétillante 33cl', 'quantity': 1, 'options': []},
        {'name': 'Tiramisu Artisanal', 'quantity': 1, 'options': []},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> addTip(
    String orderId,
    Map<String, dynamic> tipData,
  ) async {
    final tip = {
      'id': 'tip_${DateTime.now().millisecondsSinceEpoch}',
      'orderId': orderId,
      'amount': tipData['amount'] ?? 2.0,
      'percentage': tipData['percentage'],
      'thankYouMessage': tipData['thankYouMessage'],
      'paidAt': DateTime.now().toIso8601String(),
      'paymentMethod': tipData['paymentMethod'] ?? 'card',
      'createdAt': DateTime.now().toIso8601String(),
    };
    _mockTips.putIfAbsent(orderId, () => []).add(tip);
    return tip;
  }

  @override
  Future<Map<String, dynamic>> getTip(String orderId) async {
    final list = _mockTips[orderId] ?? [];
    return {'tips': list, 'count': list.length};
  }

  @override
  Future<Map<String, dynamic>> getCourierTips(String courierId) async {
    return {
      'tips': [
        {
          'id': 'tip_demo_1',
          'orderId': 'order_1',
          'amount': 3.50,
          'percentage': 15.0,
          'thankYouMessage': 'Merci pour la rapidité !',
          'orderReference': 'SF-1024',
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'id': 'tip_demo_2',
          'orderId': 'order_2',
          'amount': 2.00,
          'percentage': 10.0,
          'thankYouMessage': 'Super livreur, très poli',
          'orderReference': 'SF-1020',
          'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
      ],
      'totalEarned': 5.50,
      'count': 2,
    };
  }
}
