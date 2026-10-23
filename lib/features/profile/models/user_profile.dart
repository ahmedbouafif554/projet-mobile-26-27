/// Informations de l'utilisateur connecté.
class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.loyaltyPoints,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String avatarUrl;
  final int loyaltyPoints;

  String get fullName => '$firstName $lastName';

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) => UserProfile(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    avatarUrl: avatarUrl,
    loyaltyPoints: loyaltyPoints,
  );
}
