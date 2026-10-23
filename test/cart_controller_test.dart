import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/features/catalog/data/catalog_mock_data.dart';
import 'package:superfaster/features/orders/models/cart_item.dart';
import 'package:superfaster/features/orders/presentation/controllers/cart_controller.dart';

/// Tests unitaires de la logique du panier (calculs et codes promo).
void main() {
  late CartController cart;

  setUp(() => cart = CartController());

  test('fusionne deux ajouts identiques sur une seule ligne', () {
    final product = CatalogMockData.productById('r1-classic');
    cart.add(CartItem.withDefaults(product));
    cart.add(CartItem.withDefaults(product));

    expect(cart.items, hasLength(1));
    expect(cart.itemCount, 2);
    expect(cart.subtotal, closeTo(product.price * 2, 0.001));
  });

  test('applique un code promo en pourcentage', () {
    cart.add(
      CartItem(
        product: CatalogMockData.productById('r2-margherita'),
        quantity: 2,
      ),
    );
    expect(cart.applyPromo('bienvenue30'), isTrue);
    expect(cart.discount, closeTo(cart.subtotal * 0.3, 0.001));
  });

  test('refuse un code promo inconnu', () {
    cart.add(CartItem(product: CatalogMockData.productById('r2-margherita')));
    expect(cart.applyPromo('FAUX'), isFalse);
    expect(cart.promo, isNull);
  });

  test('LIVRAISON annule les frais de livraison', () {
    cart.add(CartItem(product: CatalogMockData.productById('r2-margherita')));
    expect(cart.deliveryFee, greaterThan(0));
    cart.applyPromo('LIVRAISON');
    expect(cart.deliveryFee, 0);
  });

  test('une quantité à zéro supprime la ligne', () {
    final item = CartItem(product: CatalogMockData.productById('r3-sakura'));
    cart.add(item);
    cart.updateQuantity(item.key, 0);
    expect(cart.isEmpty, isTrue);
  });
}
