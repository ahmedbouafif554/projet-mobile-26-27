import '../../models/product.dart';
import '../base/crud_repository.dart';

/// Produits des restaurants (Module 2).
abstract interface class ProductRepository implements CrudRepository<Product> {
  Future<List<Product>> forRestaurant(String restaurantId);

  /// Interrupteur disponible / rupture.
  Future<Product> setAvailability(String id, bool isAvailable);
}
