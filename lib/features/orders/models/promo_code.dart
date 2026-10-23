/// Type de réduction d'un code promo.
enum PromoType { percent, fixed, freeDelivery }

/// Code promo applicable dans le panier.
class PromoCode {
  const PromoCode({
    required this.code,
    required this.description,
    required this.type,
    this.value = 0,
  });

  final String code;
  final String description;
  final PromoType type;

  /// Pourcentage (30 = 30 %) ou montant fixe en euros.
  final double value;

  /// Montant de la réduction sur le sous-total.
  double discountOn(double subtotal) => switch (type) {
    PromoType.percent => subtotal * value / 100,
    PromoType.fixed => value > subtotal ? subtotal : value,
    PromoType.freeDelivery => 0,
  };
}
