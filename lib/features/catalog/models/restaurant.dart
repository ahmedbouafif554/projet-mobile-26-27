/// Restaurant ou commerce (les épiceries utilisent le même modèle).
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.cuisine,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.deliveryMinutes,
    required this.deliveryFee,
    required this.distanceKm,
    required this.address,
    required this.description,
    this.promo,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String categoryId;

  /// Libellé court affiché sous le nom (ex. : « Burgers • Américain »).
  final String cuisine;
  final String imageUrl;
  final double rating;
  final int reviewCount;

  /// Temps de livraison moyen en minutes.
  final int deliveryMinutes;
  final double deliveryFee;
  final double distanceKm;
  final String address;
  final String description;

  /// Texte de promotion éventuel (ex. : « -20% »).
  final String? promo;
  final bool isPopular;

  bool get hasFreeDelivery => deliveryFee == 0;

  /// « 20-30 min »
  String get deliveryTimeLabel =>
      '${deliveryMinutes - 5}-${deliveryMinutes + 5} min';
}
