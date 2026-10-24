import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/models.dart';
import '../../../../shared/repositories/repository_providers.dart';

/// Panier du client (Module 3) : ajout (les lignes identiques sont
/// fusionnées), quantités, suppression. Un panier ne contient que des
/// produits d'un seul restaurant.
final cartProvider = AsyncNotifierProvider<CartController, List<CartItem>>(
  CartController.new,
);

class CartController extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() => ref.watch(cartRepositoryProvider).getAll();

  List<CartItem> get _items => state.value ?? const [];

  /// Restaurant du panier (null si vide).
  String? get restaurantId => _items.firstOrNull?.product.restaurantId;

  /// Vrai si [product] vient d'un autre restaurant que le panier.
  bool conflictsWith(Product product) =>
      restaurantId != null && restaurantId != product.restaurantId;

  Future<void> add(
    Product product, {
    int quantity = 1,
    List<ProductOption> options = const [],
    String? note,
  }) async {
    final repository = ref.read(cartRepositoryProvider);
    final draft = CartItem(
      id: '',
      product: product,
      quantity: quantity,
      options: options,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );
    final existing = _items
        .where((i) => i.mergeKey == draft.mergeKey)
        .firstOrNull;
    existing == null
        ? await repository.create(draft)
        : await repository.update(
            existing.copyWith(quantity: existing.quantity + quantity),
          );
    await _reload();
  }

  /// Nouvelle quantité (0 retire la ligne). Mise à jour optimiste.
  Future<void> setQuantity(CartItem item, int quantity) async {
    if (quantity <= 0) return remove(item);
    state = AsyncData([
      for (final i in _items) i.id == item.id ? i.copyWith(quantity: quantity) : i,
    ]);
    await ref.read(cartRepositoryProvider).update(item.copyWith(quantity: quantity));
  }

  Future<void> remove(CartItem item) async {
    state = AsyncData([for (final i in _items) if (i.id != item.id) i]);
    await ref.read(cartRepositoryProvider).delete(item.id);
  }

  /// Remet une ligne supprimée (bouton « Annuler » du snackbar).
  Future<void> restore(CartItem item) async {
    await ref.read(cartRepositoryProvider).create(item.copyWith(id: ''));
    await _reload();
  }

  Future<void> clear() async {
    await ref.read(cartRepositoryProvider).clear();
    state = const AsyncData([]);
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Totaux du panier.
class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    this.discount = 0,
  });

  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;

  double get total =>
      (subtotal + deliveryFee + serviceFee - discount).clamp(0, double.infinity);

  /// Frais de service : 5 % du sous-total, entre 0,49 € et 1,99 €.
  static double serviceFor(double subtotal) =>
      subtotal == 0 ? 0 : (subtotal * 0.05).clamp(0.49, 1.99);

  static CartTotals of(
    List<CartItem> items,
    Restaurant? restaurant, {
    double discount = 0,
  }) {
    final subtotal = items.fold<double>(0, (s, i) => s + i.totalPrice);
    return CartTotals(
      subtotal: subtotal,
      deliveryFee: items.isEmpty ? 0 : restaurant?.deliveryFee ?? 0,
      serviceFee: serviceFor(subtotal),
      discount: discount,
    );
  }
}

/// Codes promo de démonstration.
class PromoCodes {
  PromoCodes._();

  /// Réduction du code sur un sous-total (null si le code est invalide).
  static double? discountFor(String code, double subtotal, double deliveryFee) {
    switch (code.trim().toUpperCase()) {
      case 'SUPER10':
        return (subtotal * 0.10 * 100).roundToDouble() / 100;
      case 'BIENVENUE':
        return subtotal >= 15 ? 5 : null;
      case 'LIVRAISON':
        return deliveryFee;
      default:
        return null;
    }
  }

  static const hint = 'Essayez SUPER10, BIENVENUE ou LIVRAISON';
}
