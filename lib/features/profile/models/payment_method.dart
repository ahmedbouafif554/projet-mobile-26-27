/// Types de moyens de paiement proposés.
enum PaymentType { visa, mastercard, paypal, applePay, cash }

/// Moyen de paiement enregistré (fictif).
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    this.last4,
    this.expiry,
    this.holder,
  });

  final String id;
  final PaymentType type;
  final String label;
  final String? last4;
  final String? expiry;
  final String? holder;

  bool get isCard => type == PaymentType.visa || type == PaymentType.mastercard;

  /// « Visa •••• 4242 » ou « PayPal »
  String get displayLabel => last4 == null ? label : '$label •••• $last4';
}
