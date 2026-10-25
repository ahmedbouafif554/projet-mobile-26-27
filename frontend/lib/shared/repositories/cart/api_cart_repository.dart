import '../../../core/network/api_exception.dart';
import '../../models/cart_item.dart';
import '../base/api_crud_repository.dart';
import 'cart_repository.dart';

class ApiCartRepository extends ApiCrudRepository<CartItem>
    implements CartRepository {
  ApiCartRepository(super.dio) : super(path: '/cart/items');

  @override
  CartItem fromJson(Map<String, dynamic> json) => CartItem.fromJson(json);

  @override
  Map<String, dynamic> toJson(CartItem item) => item.toJson();

  @override
  String idOf(CartItem item) => item.id;

  @override
  Future<void> clear() => runApi(() => dio.delete<void>(path));
}
