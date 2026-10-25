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
}
