import '../../catalog/models/product.dart';

/// Ligne du panier : un produit avec ses options et sa quantité.
class CartItem {
  const CartItem({
    required this.product,
    this.size,
    this.extras = const [],
    this.quantity = 1,
    this.note,
  });

  /// Article avec les options par défaut (première taille, sans supplément).
  /// Utilisé par l'ajout rapide « + » depuis le menu.
  factory CartItem.withDefaults(Product product) {
    for (final group in product.optionGroups) {
      if (group.isRequired &&
          !group.allowMultiple &&
          group.options.isNotEmpty) {
        return CartItem(product: product, size: group.options.first);
      }
    }
    return CartItem(product: product);
  }

  final Product product;
  final ProductOption? size;
  final List<ProductOption> extras;
  final int quantity;
  final String? note;

  /// Identifiant unique : même produit + mêmes options = même ligne.
  String get key {
    final extraIds = extras.map((e) => e.id).toList()..sort();
    return '${product.id}|${size?.id ?? ''}|${extraIds.join(',')}|${note ?? ''}';
  }

  double get unitPrice =>
      product.price +
      (size?.extraPrice ?? 0) +
      extras.fold<double>(0, (sum, e) => sum + e.extraPrice);

  double get totalPrice => unitPrice * quantity;

  /// « Grand • Bacon croustillant • Cheddar affiné »
  String get optionsLabel =>
      [if (size != null) size!.name, ...extras.map((e) => e.name)].join(' • ');

  CartItem copyWith({int? quantity}) => CartItem(
    product: product,
    size: size,
    extras: extras,
    quantity: quantity ?? this.quantity,
    note: note,
  );
}
