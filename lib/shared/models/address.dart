import 'json_utils.dart';

enum AddressType {
  home('Domicile'),
  work('Travail'),
  other('Autre');

  const AddressType(this.label);
  final String label;
}

/// Adresse de livraison d'un utilisateur.
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.street,
    required this.postalCode,
    required this.city,
    this.type = AddressType.home,
    this.instructions,
    this.isDefault = false,
    this.latitude = 48.8566,
    this.longitude = 2.3522,
  });

  final String id;
  final String userId;
  final String label;
  final String street;
  final String postalCode;
  final String city;
  final AddressType type;
  final String? instructions;
  final bool isDefault;
  final double latitude;
  final double longitude;

  /// « 12 rue de la Paix, 75002 Paris »
  String get fullAddress => '$street, $postalCode $city';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: json['id'] as String,
    userId: json['userId'] as String,
    label: json['label'] as String,
    street: json['street'] as String,
    postalCode: json['postalCode'] as String,
    city: json['city'] as String,
    type: parseEnum(AddressType.values, json['type'], AddressType.other),
    instructions: json['instructions'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
    latitude: parseDouble(json['latitude'], 48.8566),
    longitude: parseDouble(json['longitude'], 2.3522),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'label': label,
    'street': street,
    'postalCode': postalCode,
    'city': city,
    'type': type.name,
    'instructions': instructions,
    'isDefault': isDefault,
    'latitude': latitude,
    'longitude': longitude,
  };

  Address copyWith({
    String? id,
    String? userId,
    String? label,
    String? street,
    String? postalCode,
    String? city,
    AddressType? type,
    Object? instructions = keep,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) => Address(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    label: label ?? this.label,
    street: street ?? this.street,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    type: type ?? this.type,
    instructions: instructions == keep
        ? this.instructions
        : instructions as String?,
    isDefault: isDefault ?? this.isDefault,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
}
