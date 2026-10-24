import '../../models/product.dart';
import '../base/mock_crud_repository.dart';
import 'product_repository.dart';

class MockProductRepository extends MockCrudRepository<Product>
    implements ProductRepository {
  MockProductRepository(super.seed) : super(idPrefix: 'p');

  @override
  String idOf(Product item) => item.id;

  @override
  Product withId(Product item, String id) => item.copyWith(id: id);

  @override
  Future<List<Product>> forRestaurant(String restaurantId) =>
      where((p) => p.restaurantId == restaurantId);

  @override
  Future<Product> setAvailability(String id, bool isAvailable) =>
      mutate(id, (p) => p.copyWith(isAvailable: isAvailable));
}
