import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/mock/mock_images.dart';
import '../../shared/models/courier.dart';
import '../../shared/models/restaurant.dart';
import '../../shared/models/user.dart';
import '../../shared/repositories/repository_providers.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'permissions.dart';

/// Session courante : utilisateur connecté (ou null).
class AuthState {
  const AuthState({this.user});

  final User? user;

  bool get isLoggedIn => user != null;
  UserRole? get role => user?.role;

  bool can(Permission permission) => Permissions.can(role, permission);
}

/// Session partagée par les routeurs (redirect) et les écrans.
final authServiceProvider = NotifierProvider<AuthService, AuthState>(
  AuthService.new,
);

/// Authentification mock : vérifie l'e-mail dans le dépôt des utilisateurs
/// et accepte tout mot de passe de 6 caractères ou plus.
/// À remplacer par un appel `POST /auth/login` quand l'API sera prête.
class AuthService extends Notifier<AuthState> {
  /// Code de vérification accepté par le mock (écran OTP).
  static const demoOtpCode = '1234';

  @override
  AuthState build() => const AuthState();

  /// Connexion. [space] refuse les comptes de l'autre application (un client
  /// ne peut pas se connecter à l'Espace Pro) ; [role] vérifie le rôle choisi
  /// sur l'écran de connexion (client ou livreur).
  Future<User> login({
    required String email,
    required String password,
    AppSpace? space,
    UserRole? role,
  }) async {
    if (password.length < 6) {
      throw const ApiException('Mot de passe incorrect.', statusCode: 401);
    }
    final user = await ref.read(userRepositoryProvider).findByEmail(email);
    if (user == null) {
      throw const ApiException(
        'Aucun compte ne correspond à cet e-mail.',
        statusCode: 401,
      );
    }
    if (role != null &&
        user.role != role &&
        Permissions.canAccess(user.role, AppSpace.frontOffice)) {
      throw ApiException(
        'Ce compte est un compte ${user.role.label.toLowerCase()} : '
        'sélectionnez « ${user.role.label} ».',
        statusCode: 403,
      );
    }
    return _open(user, space);
  }

  /// Connexion rapide de démonstration avec le premier compte actif du rôle.
  Future<User> loginAs(UserRole role) async {
    final users = await ref.read(userRepositoryProvider).getAll();
    final user = users.firstWhere(
      (u) => u.role == role && u.status == UserStatus.active,
    );
    return _open(user, Permissions.spaceOf(role));
  }

  /// Inscription (front office) d'un client ou d'un livreur. Le compte est
  /// créé, mais la session ne s'ouvre qu'après la vérification du numéro
  /// ([verifyOtp]). Un livreur reçoit aussi un profil dont les justificatifs
  /// seront validés dans le back office.
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    UserRole role = UserRole.client,
  }) async {
    if (!Permissions.canAccess(role, AppSpace.frontOffice)) {
      throw const ApiException(
        "Ce type de compte s'inscrit dans l'Espace Pro.",
      );
    }
    final repository = ref.read(userRepositoryProvider);
    if (await repository.findByEmail(email) != null) {
      throw const ApiException('Un compte existe déjà avec cet e-mail.');
    }
    final now = DateTime.now();
    final user = await repository.create(
      User(
        id: '',
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        role: role,
        createdAt: now,
      ),
    );
    if (role == UserRole.courier) {
      await ref
          .read(courierRepositoryProvider)
          .create(
            Courier(
              id: '',
              userId: user.id,
              firstName: firstName,
              lastName: lastName,
              phone: phone,
              documents: [
                for (final type in DocumentType.values)
                  CourierDocument(type: type, uploadedAt: now),
              ],
              joinedAt: now,
            ),
          );
    }
    return user;
  }

  /// Demande d'inscription d'un restaurant (Espace Pro) : le compte du
  /// restaurateur et le restaurant sont créés « en attente » ; l'admin les
  /// valide dans le back office (Catalogue › Restaurants).
  Future<Restaurant> registerRestaurant({
    required String restaurantName,
    required String cuisine,
    required String address,
    required String phone,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final users = ref.read(userRepositoryProvider);
    if (await users.findByEmail(email) != null) {
      throw const ApiException('Un compte existe déjà avec cet e-mail.');
    }
    final now = DateTime.now();
    final owner = await users.create(
      User(
        id: '',
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        role: UserRole.restaurant,
        status: UserStatus.pending,
        createdAt: now,
      ),
    );
    final restaurant = await ref
        .read(restaurantRepositoryProvider)
        .create(
          Restaurant(
            id: '',
            ownerId: owner.id,
            name: restaurantName,
            description: 'Nouveau restaurant partenaire.',
            cuisine: cuisine,
            categoryIds: const [],
            imageUrl: unsplash('1517248135467-4c7edcad34c4'),
            address: address,
            phone: phone,
            status: RestaurantStatus.pending,
            createdAt: now,
          ),
        );
    await users.update(owner.copyWith(restaurantId: restaurant.id));
    return restaurant;
  }

  /// Vérifie le code reçu par SMS (mock : [demoOtpCode]) puis ouvre la
  /// session du compte créé à l'inscription.
  Future<User> verifyOtp({required String userId, required String code}) async {
    if (code != demoOtpCode) {
      throw const ApiException('Code incorrect, veuillez réessayer.');
    }
    final user = await ref.read(userRepositoryProvider).getById(userId);
    return _open(user, AppSpace.frontOffice);
  }

  User _open(User user, AppSpace? space) {
    if (user.isBlocked) {
      throw const ApiException(
        'Ce compte est bloqué. Contactez le support.',
        statusCode: 403,
      );
    }
    if (user.role == UserRole.restaurant && user.status == UserStatus.pending) {
      throw const ApiException(
        'Votre inscription est en cours de validation par notre équipe.',
        statusCode: 403,
      );
    }
    if (space != null && !Permissions.canAccess(user.role, space)) {
      throw ApiException(
        space == AppSpace.backOffice
            ? "L'Espace Pro est réservé aux restaurants et à l'administration."
            : "Ce compte n'a pas accès à l'application mobile.",
        statusCode: 403,
      );
    }
    // Jeton fictif : les dépôts API l'enverront dans l'en-tête Authorization.
    ref.read(authTokenProvider.notifier).set('mock-token-${user.id}');
    state = AuthState(user: user.copyWith(lastLoginAt: DateTime.now()));
    return state.user!;
  }

  /// Met à jour l'utilisateur affiché (après modification du profil).
  void updateUser(User user) => state = AuthState(user: user);

  void logout() {
    ref.read(authTokenProvider.notifier).set(null);
    state = const AuthState();
  }
}
