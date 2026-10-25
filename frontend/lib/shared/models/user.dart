import 'json_utils.dart';

/// Rôles de la plateforme : client et livreur (front office),
/// restaurant et admin (back office).
enum UserRole {
  client('Client'),
  courier('Livreur'),
  restaurant('Restaurant'),
  admin('Administrateur');

  const UserRole(this.label);
  final String label;
}

enum UserStatus {
  active('Actif'),
  blocked('Bloqué'),
  pending('En attente');

  const UserStatus(this.label);
  final String label;
}

/// Utilisateur de la plateforme (tous rôles confondus).
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.status = UserStatus.active,
    this.avatarUrl,
    this.restaurantId,
    this.loyaltyPoints = 0,
    required this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final UserRole role;
  final UserStatus status;
  final String? avatarUrl;

  /// Restaurant géré (rôle restaurant uniquement).
  final String? restaurantId;
  final int loyaltyPoints;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();

  bool get isBlocked => status == UserStatus.blocked;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String? ?? '',
    role: parseEnum(UserRole.values, json['role'], UserRole.client),
    status: parseEnum(UserStatus.values, json['status'], UserStatus.active),
    avatarUrl: json['avatarUrl'] as String?,
    restaurantId: json['restaurantId'] as String?,
    loyaltyPoints: parseInt(json['loyaltyPoints']),
    createdAt: parseDate(json['createdAt']),
    lastLoginAt: parseDateOrNull(json['lastLoginAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'role': role.name,
    'status': status.name,
    'avatarUrl': avatarUrl,
    'restaurantId': restaurantId,
    'loyaltyPoints': loyaltyPoints,
    'createdAt': createdAt.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    UserRole? role,
    UserStatus? status,
    Object? avatarUrl = keep,
    Object? restaurantId = keep,
    int? loyaltyPoints,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) => User(
    id: id ?? this.id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    status: status ?? this.status,
    avatarUrl: avatarUrl == keep ? this.avatarUrl : avatarUrl as String?,
    restaurantId: restaurantId == keep
        ? this.restaurantId
        : restaurantId as String?,
    loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
    createdAt: createdAt ?? this.createdAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
  );
}
