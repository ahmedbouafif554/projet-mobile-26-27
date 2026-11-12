import '../../../core/network/api_exception.dart';
import '../../models/food_info.dart';
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

  /// Démo hors connexion : un seul produit connu (le pot de Nutella 400 g).
  static const demoBarcode = '3017620422003';

  @override
  Future<BarcodeProduct> lookupBarcode(String barcode) async {
    await latency();
    final code = barcode.replaceAll(RegExp(r'[\s-]'), '');
    if (!isValidBarcode(code)) {
      throw const ApiException(
        'Code-barres invalide : 8, 12, 13 ou 14 chiffres avec une clé de '
        'contrôle correcte.',
        statusCode: 422,
      );
    }
    if (code != demoBarcode) {
      throw const ApiException(
        'Aucun produit ne correspond à ce code-barres sur Open Food Facts.',
        statusCode: 404,
      );
    }
    return const BarcodeProduct(
      barcode: demoBarcode,
      name: 'Nutella',
      description: 'Ferrero · 400 g',
      imageUrl:
          'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.jpg',
      calories: 539,
      caloriesPer100g: true,
      allergens: ['milk', 'nuts', 'soybeans'],
      nutriScore: NutriScore.e,
    );
  }
}
