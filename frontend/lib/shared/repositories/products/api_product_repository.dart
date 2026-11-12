import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../models/food_info.dart';
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

  @override
  Future<BarcodeProduct> lookupBarcode(String barcode) => runApi(() async {
    final code = barcode.replaceAll(RegExp(r'[\s-]'), '');
    final response = await dio.get('$path/lookup/$code');
    return BarcodeProduct.fromJson(jsonMap(response.data));
  });
}
