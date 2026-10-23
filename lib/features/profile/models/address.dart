/// Type d'adresse (détermine l'icône affichée).
enum AddressType { home, work, other }

/// Adresse de livraison enregistrée.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    this.type = AddressType.other,
    this.instructions,
  });

  final String id;

  /// Nom donné par l'utilisateur (« Maison », « Bureau »...).
  final String label;
  final String street;
  final String city;
  final AddressType type;

  /// Digicode, étage, etc.
  final String? instructions;

  String get fullAddress => '$street, $city';
}
