import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/mock/mock_images.dart';
import '../../shared/mock/mock_users.dart';
import '../../shared/models/courier.dart';
import '../../shared/models/restaurant.dart';
import '../../shared/models/user.dart';
import '../../shared/repositories/repository_providers.dart';
import '../config/app_config.dart';
import 'google_auth.dart';
import 'session_store.dart';
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

/// Connexion et inscription. En mode API, le mot de passe est vérifié
/// par le serveur et le compte est enregistré dans MySQL.
class AuthService extends Notifier<AuthState> {
  /// Code de vérification accepté par le mock (écran OTP).
  static const demoOtpCode = '1234';

  @override
  AuthState build() {
    final saved = readSession();
    final rawUser = saved?['user'];
    final token = saved?['token'];
    if (rawUser is! Map || token is! String || token.isEmpty) {
      return const AuthState();
    }
    try {
      final user = User.fromJson(Map<String, dynamic>.from(rawUser));
      // Session reprise : le serveur confirme qu'elle est toujours valide.
      if (AppConfig.useApiAuth) Future.microtask(() => _confirmSession(token));
      return AuthState(user: user);
    } catch (_) {
      writeSession(null);
      return const AuthState();
    }
  }

  /// Relit le profil avec le jeton enregistré. Jeton révoqué ou expiré,
  /// compte bloqué ou supprimé : déconnexion. Hors connexion : la session
  /// est gardée (l'appli fonctionne dès que le réseau revient).
  Future<void> _confirmSession(String token) async {
    try {
      final response = await _dio().get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (ref.read(authTokenProvider) != token) return;
      final user = User.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      state = AuthState(user: user);
      _remember(user, token);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if ((status == 401 || status == 403) &&
          ref.read(authTokenProvider) == token) {
        logout();
      }
    } catch (_) {
      // Réponse illisible : on garde la session telle quelle.
    }
  }

  /// Connexion. [space] refuse les comptes de l'autre application (un client
  /// ne peut pas se connecter à l'Espace Pro) ; [role] vérifie le rôle choisi
  /// sur l'écran de connexion (client ou livreur).
  Future<User> login({
    required String email,
    required String password,
    AppSpace? space,
    UserRole? role,
  }) async {
    if (AppConfig.useApiAuth) {
      return _acceptSession(
        await _post('/auth/login', {
          'email': email.trim(),
          'password': password,
          if (role != null) 'role': role.name,
          if (space != null) 'space': space.name,
        }),
      );
    }
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
    await _ensureCourierApproved(user);
    return _open(user, space);
  }

  /// Connexion rapide de démonstration avec le premier compte actif du rôle.
  Future<User> loginAs(UserRole role) async {
    if (AppConfig.useApiAuth) {
      const emails = {
        UserRole.client: DemoAccounts.client,
        UserRole.courier: DemoAccounts.courier,
        UserRole.restaurant: DemoAccounts.restaurant,
        UserRole.admin: DemoAccounts.admin,
      };
      return login(
        email: emails[role]!,
        password: DemoAccounts.password,
        space: Permissions.spaceOf(role),
        role: role,
      );
    }
    final users = await ref.read(userRepositoryProvider).getAll();
    final user = users.firstWhere(
      (u) => u.role == role && u.status == UserStatus.active,
    );
    await _ensureCourierApproved(user);
    return _open(user, Permissions.spaceOf(role));
  }

  /// Inscription (front office) d'un client ou d'un livreur.
  /// Le client est connecté tout de suite. Le livreur reçoit un profil
  /// en attente : la session ne s'ouvre qu'après validation par un admin.
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    UserRole role = UserRole.client,
    List<Map<String, String>>? documents,
  }) async {
    if (!Permissions.canAccess(role, AppSpace.frontOffice)) {
      throw const ApiException(
        "Ce type de compte s'inscrit dans l'Espace Pro.",
      );
    }
    if (AppConfig.useApiAuth) {
      final body = await _post('/auth/register', {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'role': role.name,
        if (role == UserRole.courier) 'documents': documents,
      });
      final token = body['token'];
      if (role == UserRole.courier && (token is! String || token.isEmpty)) {
        return User.fromJson(Map<String, dynamic>.from(body['user'] as Map));
      }
      return _acceptSession(body);
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
      return user;
    }
    return _open(user, AppSpace.frontOffice);
  }

  /// Le livreur de démo a des justificatifs déjà validés. Un nouveau
  /// livreur reste bloqué tant que l'admin ne les a pas acceptés.
  Future<void> _ensureCourierApproved(User user) async {
    if (user.role != UserRole.courier) return;
    final courier = await ref
        .read(courierRepositoryProvider)
        .findByUser(user.id);
    if (courier?.documentStatus == DocumentStatus.approved) return;
    throw ApiException(
      courier?.documentStatus == DocumentStatus.rejected
          ? 'Vos justificatifs ont été refusés. Vous ne pouvez pas vous connecter.'
          : 'Votre compte livreur est en attente de validation par un administrateur.',
      statusCode: 403,
    );
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
    if (AppConfig.useApiAuth) {
      final body = await _post('/auth/register-restaurant', {
        'restaurantName': restaurantName.trim(),
        'cuisine': cuisine.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'password': password,
      });
      return Restaurant.fromJson(
        Map<String, dynamic>.from(body['restaurant'] as Map),
      );
    }
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
    if (AppConfig.useApiAuth) {
      return _acceptSession(
        await _post('/auth/verify-otp', {'userId': userId, 'code': code}),
      );
    }
    if (code != demoOtpCode) {
      throw const ApiException('Code incorrect, veuillez réessayer.');
    }
    final user = await ref.read(userRepositoryProvider).getById(userId);
    return _open(user, AppSpace.frontOffice);
  }

  /// Connexion avec Google. En mode API, l'ID token Google est vérifié par
  /// le serveur (création d'un compte client si besoin). En démonstration,
  /// le compte de démo du rôle choisi est ouvert.
  Future<User> loginWithGoogle({UserRole? role, AppSpace? space}) async {
    if (!AppConfig.useApiAuth) return loginAs(role ?? UserRole.client);
    if (!AppConfig.googleSignInEnabled) {
      throw const ApiException("La connexion Google n'est pas configurée.");
    }
    final idToken = await GoogleAuth.idToken();
    return _acceptSession(
      await _post('/auth/google', {
        'idToken': idToken,
        if (role != null) 'role': role.name,
        if (space != null) 'space': space.name,
      }),
    );
  }

  /// « Mot de passe oublié » : le serveur envoie un lien par e-mail (même
  /// réponse que le compte existe ou non).
  Future<void> requestPasswordReset(String email) async {
    if (!AppConfig.useApiAuth) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return;
    }
    await _post('/auth/forgot-password', {'email': email.trim()});
  }

  /// Nouveau mot de passe depuis le compte. Le serveur ferme les autres
  /// sessions et renvoie un nouveau jeton pour cet appareil.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!AppConfig.useApiAuth) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return;
    }
    _acceptSession(
      await _post('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }, token: ref.read(authTokenProvider)),
    );
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
    final opened = user.copyWith(lastLoginAt: DateTime.now());
    ref.read(authTokenProvider.notifier).set('mock-token-${user.id}');
    state = AuthState(user: opened);
    _remember(opened, 'mock-token-${user.id}');
    return opened;
  }

  /// Met à jour l'utilisateur affiché (après modification du profil).
  void updateUser(User user) {
    state = AuthState(user: user);
    _remember(user, ref.read(authTokenProvider));
  }

  /// Rouvre une session client déjà vérifiée par la biométrie de l'appareil.
  User restoreBiometricSession({required User user, required String token}) {
    if (user.role != UserRole.client) {
      throw const ApiException(
        'La reconnaissance faciale est réservée aux comptes client.',
      );
    }
    ref.read(authTokenProvider.notifier).set(token);
    state = AuthState(user: user);
    _remember(user, token);
    return user;
  }

  void logout() {
    if (state.user == null && ref.read(authTokenProvider) == null) return;
    GoogleAuth.signOut();
    ref.read(authTokenProvider.notifier).set(null);
    writeSession(null);
    state = const AuthState();
  }

  void _remember(User user, String? token) {
    if (token == null || token.isEmpty) return;
    writeSession({'user': user.toJson(), 'token': token});
  }

  Dio _dio() => Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    try {
      final response = await _dio().post(
        path,
        data: data,
        options: token == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);
      throw const ApiException('Réponse du serveur illisible.');
    } on DioException catch (error) {
      throw _authException(error);
    }
  }

  User _acceptSession(Map<String, dynamic> body) {
    final user = User.fromJson(Map<String, dynamic>.from(body['user'] as Map));
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Le serveur n\'a pas renvoyé de session.');
    }
    ref.read(authTokenProvider.notifier).set(token);
    state = AuthState(user: user);
    _remember(user, token);
    return user;
  }

  ApiException _authException(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(
        data['error'] as String,
        statusCode: error.response?.statusCode,
      );
    }
    return ApiException.fromDio(error);
  }
}
