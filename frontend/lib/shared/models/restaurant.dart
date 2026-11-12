import 'json_utils.dart';

/// Cycle de vie d'un restaurant : demande d'inscription → validé (ou refusé),
/// puis éventuellement suspendu par l'admin.
enum RestaurantStatus {
  pending('Demande en attente'),
  approved('Validé'),
  rejected('Refusé'),
  suspended('Suspendu');

  const RestaurantStatus(this.label);
  final String label;
}

/// Localisation de l'adresse du restaurant (OpenStreetMap, côté serveur).
/// [code] est la valeur JSON envoyée par l'API.
enum RestaurantLocationStatus {
  pending('pending', 'À localiser'),
  ok('ok', 'Localisé sur la carte'),
  notFound('not_found', 'Adresse introuvable'),
  error('error', 'Localisation à réessayer'),
  manual('manual', 'Position saisie à la main');

  const RestaurantLocationStatus(this.code, this.label);
  final String code;
  final String label;

  static RestaurantLocationStatus fromCode(Object? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => pending,
  );
}

/// Restaurant ou commerce (épicerie) proposant ses produits à la livraison.
class Restaurant {
  const Restaurant({
    required this.id,
    this.ownerId,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.categoryIds,
    required this.imageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.deliveryMinutes = 30,
    this.deliveryFee = 0,
    this.minOrder = 10,
    this.distanceKm = 1,
    required this.address,
    required this.phone,
    this.menuSections = const [],
    this.menuImageUrl,
    this.latitude,
    this.longitude,
    this.locationStatus = RestaurantLocationStatus.pending,
    this.estimatedMinutes,
    this.isOpen = true,
    this.isPopular = false,
    this.promo,
    this.status = RestaurantStatus.approved,
    required this.createdAt,
  });

  final String id;

  /// Utilisateur (rôle restaurant) qui gère ce restaurant.
  final String? ownerId;
  final String name;
  final String description;

  /// « Burgers • Américain »
  final String cuisine;
  final List<String> categoryIds;
  final String imageUrl;
  final double rating;
  final int reviewCount;

  /// Temps de livraison moyen (minutes).
  final int deliveryMinutes;
  final double deliveryFee;
  final double minOrder;
  final double distanceKm;
  final String address;
  final String phone;

  /// Onglets du menu, dans l'ordre d'affichage.
  final List<String> menuSections;

  /// Photo de la carte importée depuis le téléphone (data URI) ou lien web.
  final String? menuImageUrl;

  /// Position GPS de l'adresse (trouvée par OpenStreetMap ou saisie).
  final double? latitude;
  final double? longitude;
  final RestaurantLocationStatus locationStatus;

  /// Délai estimé depuis la position du client (null si elle est inconnue).
  /// [distanceKm] est alors la distance réelle jusqu'au client.
  final int? estimatedMinutes;
  final bool isOpen;
  final bool isPopular;

  /// Offre en cours (« -20 % », « Livraison offerte »…).
  final String? promo;
  final RestaurantStatus status;
  final DateTime createdAt;

  /// Visible par les clients du front office.
  bool get isVisible => status == RestaurantStatus.approved;

  /// Coordonnées fiables : le restaurant apparaît sur la carte et dans
  /// « Près de moi ».
  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      (locationStatus == RestaurantLocationStatus.ok ||
          locationStatus == RestaurantLocationStatus.manual);

  /// « 20-30 min » (délai estimé depuis le client quand il est connu).
  String get deliveryTimeLabel {
    final minutes = estimatedMinutes ?? deliveryMinutes;
    return '${minutes - 5}-${minutes + 5} min';
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String?,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    cuisine: json['cuisine'] as String? ?? '',
    categoryIds: parseStrings(json['categoryIds']),
    imageUrl: json['imageUrl'] as String? ?? '',
    rating: parseDouble(json['rating']),
    reviewCount: parseInt(json['reviewCount']),
    deliveryMinutes: parseInt(json['deliveryMinutes'], 30),
    deliveryFee: parseDouble(json['deliveryFee']),
    minOrder: parseDouble(json['minOrder'], 10),
    distanceKm: parseDouble(json['distanceKm'], 1),
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    menuSections: parseStrings(json['menuSections']),
    menuImageUrl: json['menuImageUrl'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    locationStatus: RestaurantLocationStatus.fromCode(json['locationStatus']),
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
    isOpen: json['isOpen'] as bool? ?? true,
    isPopular: json['isPopular'] as bool? ?? false,
    promo: json['promo'] as String?,
    status: parseEnum(
      RestaurantStatus.values,
      json['status'],
      RestaurantStatus.pending,
    ),
    createdAt: parseDate(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'description': description,
    'cuisine': cuisine,
    'categoryIds': categoryIds,
    'imageUrl': imageUrl,
    'rating': rating,
    'reviewCount': reviewCount,
    'deliveryMinutes': deliveryMinutes,
    'deliveryFee': deliveryFee,
    'minOrder': minOrder,
    'distanceKm': distanceKm,
    'address': address,
    'phone': phone,
    'menuSections': menuSections,
    'menuImageUrl': menuImageUrl,
    'latitude': latitude,
    'longitude': longitude,
    'locationStatus': locationStatus.code,
    'estimatedMinutes': estimatedMinutes,
    'isOpen': isOpen,
    'isPopular': isPopular,
    'promo': promo,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  Restaurant copyWith({
    String? id,
    Object? ownerId = keep,
    String? name,
    String? description,
    String? cuisine,
    List<String>? categoryIds,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    int? deliveryMinutes,
    double? deliveryFee,
    double? minOrder,
    double? distanceKm,
    String? address,
    String? phone,
    List<String>? menuSections,
    Object? menuImageUrl = keep,
    Object? latitude = keep,
    Object? longitude = keep,
    RestaurantLocationStatus? locationStatus,
    Object? estimatedMinutes = keep,
    bool? isOpen,
    bool? isPopular,
    Object? promo = keep,
    RestaurantStatus? status,
    DateTime? createdAt,
  }) => Restaurant(
    id: id ?? this.id,
    ownerId: ownerId == keep ? this.ownerId : ownerId as String?,
    name: name ?? this.name,
    description: description ?? this.description,
    cuisine: cuisine ?? this.cuisine,
    categoryIds: categoryIds ?? this.categoryIds,
    imageUrl: imageUrl ?? this.imageUrl,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    deliveryMinutes: deliveryMinutes ?? this.deliveryMinutes,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    minOrder: minOrder ?? this.minOrder,
    distanceKm: distanceKm ?? this.distanceKm,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    menuSections: menuSections ?? this.menuSections,
    menuImageUrl: menuImageUrl == keep
        ? this.menuImageUrl
        : menuImageUrl as String?,
    latitude: latitude == keep ? this.latitude : latitude as double?,
    longitude: longitude == keep ? this.longitude : longitude as double?,
    locationStatus: locationStatus ?? this.locationStatus,
    estimatedMinutes: estimatedMinutes == keep
        ? this.estimatedMinutes
        : estimatedMinutes as int?,
    isOpen: isOpen ?? this.isOpen,
    isPopular: isPopular ?? this.isPopular,
    promo: promo == keep ? this.promo : promo as String?,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
