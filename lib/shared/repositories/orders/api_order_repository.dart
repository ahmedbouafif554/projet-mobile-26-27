import '../../models/order.dart';
import '../base/api_crud_repository.dart';
import 'order_repository.dart';

class ApiOrderRepository extends ApiCrudRepository<Order>
    implements OrderRepository {
  ApiOrderRepository(super.dio) : super(path: '/orders');

  @override
  Order fromJson(Map<String, dynamic> json) => Order.fromJson(json);

  @override
  Map<String, dynamic> toJson(Order item) => item.toJson();

  @override
  String idOf(Order item) => item.id;

  @override
  Future<List<Order>> forUser(String userId) =>
      getList(path, query: {'userId': userId});

  @override
  Future<List<Order>> forRestaurant(String restaurantId) =>
      getList(path, query: {'restaurantId': restaurantId});

  @override
  Future<Order> updateStatus(String id, OrderStatus status, {String? note}) =>
      patch(id, 'status', {'status': status.name, 'note': note});

  @override
  Future<Order> cancel(String id, String reason) =>
      patch(id, 'cancel', {'reason': reason});

  @override
  Future<Order> refund(String id) => patch(id, 'refund');
}
