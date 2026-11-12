import '../../models/food_info.dart';
import '../../models/product.dart';
import '../base/crud_repository.dart';

/// Produits des restaurants (Module 2).
abstract interface class ProductRepository implements CrudRepository<Product> {
  Future<List<Product>> forRestaurant(String restaurantId);

  /// Interrupteur disponible / rupture.
  Future<Product> setAvailability(String id, bool isAvailable);

  /// Fiche pré-remplie par Open Food Facts pour un code-barres (rien n'est
  /// enregistré). [ApiException] 404 si le produit est inconnu.
  Future<BarcodeProduct> lookupBarcode(String barcode);
}
