import '../../models/product.dart';
import '../base/api_crud_repository.dart';
import 'product_repository.dart';

class ApiProductRepository extends ApiCrudRepository<Product>
    implements ProductRepository {
  ApiProductRepository(super.dio) : super(path: '/products');

  @override
  Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);

  @override
  Map<String, dynamic> toJson(Product item) => item.toJson();

  @override
  String idOf(Product item) => item.id;

  @override
  Future<List<Product>> forRestaurant(String restaurantId) =>
      getList('/restaurants/$restaurantId/products');

  @override
  Future<Product> setAvailability(String id, bool isAvailable) =>
      patch(id, 'availability', {'isAvailable': isAvailable});
}
