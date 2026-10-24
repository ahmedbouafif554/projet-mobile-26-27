import '../../models/cart_item.dart';
import '../base/mock_crud_repository.dart';
import 'cart_repository.dart';

class MockCartRepository extends MockCrudRepository<CartItem>
    implements CartRepository {
  MockCartRepository([super.seed = const []]) : super(idPrefix: 'ci');

  @override
  String idOf(CartItem item) => item.id;

  @override
  CartItem withId(CartItem item, String id) => item.copyWith(id: id);

  @override
  Future<void> clear() async {
    await latency();
    replaceAll(const []);
  }
}
