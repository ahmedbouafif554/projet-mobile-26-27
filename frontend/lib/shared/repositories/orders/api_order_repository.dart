import '../../../core/network/api_exception.dart';
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

  @override
  Future<Map<String, dynamic>> createPaymentIntent(String orderId) =>
      runApi(() async {
        final res = await dio.post<Map<String, dynamic>>(
          '$path/$orderId/payment-intent',
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> confirmPayment(
    String orderId, {
    String? paymentIntentId,
  }) =>
      runApi(() async {
        final res = await dio.post<Map<String, dynamic>>(
          '$path/$orderId/confirm-payment',
          data: {'paymentIntentId': paymentIntentId},
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> addGift(
    String orderId,
    Map<String, dynamic> giftData,
  ) =>
      runApi(() async {
        final res = await dio.post<Map<String, dynamic>>(
          '$path/$orderId/gift',
          data: giftData,
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> getGift(String orderId) => runApi(() async {
        final res = await dio.get<Map<String, dynamic>>('$path/$orderId/gift');
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> revealGift(String qrToken) => runApi(() async {
        final res = await dio.post<Map<String, dynamic>>(
          '$path/gifts/reveal',
          data: {'qrToken': qrToken},
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> addTip(
    String orderId,
    Map<String, dynamic> tipData,
  ) =>
      runApi(() async {
        final res = await dio.post<Map<String, dynamic>>(
          '$path/$orderId/tip',
          data: tipData,
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> getTip(String orderId) => runApi(() async {
        final res = await dio.get<Map<String, dynamic>>('$path/$orderId/tip');
        return Map<String, dynamic>.from(res.data ?? {});
      });

  @override
  Future<Map<String, dynamic>> getCourierTips(String courierId) =>
      runApi(() async {
        final res = await dio.get<Map<String, dynamic>>(
          '$path/couriers/$courierId/tips',
        );
        return Map<String, dynamic>.from(res.data ?? {});
      });
}
