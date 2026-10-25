import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/core/auth/permissions.dart';
import 'package:superfaster/core/network/api_client.dart';
import 'package:superfaster/core/network/api_exception.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/courier.dart';
import 'package:superfaster/shared/models/user.dart';
import 'package:superfaster/shared/repositories/repository_providers.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(setUpAppTestEnvironment);

  late ProviderContainer container;
  AuthService auth() => container.read(authServiceProvider.notifier);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('connexion d\'un client au front office', () async {
    final user = await auth().login(
      email: DemoAccounts.client,
      password: DemoAccounts.password,
      space: AppSpace.frontOffice,
    );
    expect(user.role, UserRole.client);
    expect(container.read(authServiceProvider).isLoggedIn, isTrue);
    expect(container.read(authTokenProvider), 'mock-token-${user.id}');

    auth().logout();
    expect(container.read(authServiceProvider).isLoggedIn, isFalse);
    expect(container.read(authTokenProvider), isNull);
  });

  test('un client ne peut pas ouvrir l\'Espace Pro', () async {
    await expectLater(
      auth().login(
        email: DemoAccounts.client,
        password: DemoAccounts.password,
        space: AppSpace.backOffice,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 403)),
    );
    expect(container.read(authServiceProvider).isLoggedIn, isFalse);
  });

  test(
    'erreurs : e-mail inconnu, mot de passe trop court, compte bloqué',
    () async {
      await expectLater(
        auth().login(email: 'inconnu@exemple.fr', password: '123456'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        auth().login(email: DemoAccounts.client, password: '123'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        auth().login(email: 'thomas.bonnet@exemple.fr', password: '123456'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 403)),
      );
    },
  );

  test('connexion rapide de démo et inscription', () async {
    expect((await auth().loginAs(UserRole.admin)).email, DemoAccounts.admin);
    expect(
      (await auth().loginAs(UserRole.courier)).email,
      DemoAccounts.courier,
    );

    final created = await auth().register(
      firstName: 'Zoé',
      lastName: 'Martin',
      email: 'zoe.martin@exemple.fr',
      phone: '0611223344',
      password: 'secret12',
    );
    expect(created.role, UserRole.client);
    // La session s'ouvre après la vérification du numéro.
    auth().logout();
    await expectLater(
      auth().verifyOtp(userId: created.id, code: '0000'),
      throwsA(isA<ApiException>()),
    );
    await auth().verifyOtp(userId: created.id, code: AuthService.demoOtpCode);
    expect(container.read(authServiceProvider).user?.id, created.id);
  });

  test('le rôle choisi à la connexion doit correspondre au compte', () async {
    await expectLater(
      auth().login(
        email: DemoAccounts.client,
        password: DemoAccounts.password,
        space: AppSpace.frontOffice,
        role: UserRole.courier,
      ),
      throwsA(isA<ApiException>()),
    );
    final courier = await auth().login(
      email: DemoAccounts.courier,
      password: DemoAccounts.password,
      space: AppSpace.frontOffice,
      role: UserRole.courier,
    );
    expect(courier.role, UserRole.courier);
  });

  test("inscription d'un livreur : profil livreur à valider", () async {
    final user = await auth().register(
      firstName: 'Sami',
      lastName: 'Kaci',
      email: 'sami.kaci@exemple.fr',
      phone: '0700000000',
      password: 'secret12',
      role: UserRole.courier,
    );
    final courier = await container
        .read(courierRepositoryProvider)
        .findByUser(user.id);
    expect(courier?.documentStatus, DocumentStatus.pending);
  });

  test('permissions par rôle', () {
    expect(
      Permissions.canAccess(UserRole.client, AppSpace.frontOffice),
      isTrue,
    );
    expect(
      Permissions.canAccess(UserRole.courier, AppSpace.backOffice),
      isFalse,
    );
    expect(
      Permissions.canAccess(UserRole.restaurant, AppSpace.backOffice),
      isTrue,
    );
    expect(Permissions.canAccess(null, AppSpace.frontOffice), isFalse);

    expect(Permissions.can(UserRole.admin, Permission.manageUsers), isTrue);
    expect(
      Permissions.can(UserRole.restaurant, Permission.manageUsers),
      isFalse,
    );
    expect(
      Permissions.can(UserRole.restaurant, Permission.manageOwnOrders),
      isTrue,
    );
    // L'admin a toutes les permissions du back office.
    for (final p in Permission.values) {
      if (p == Permission.placeOrders || p == Permission.deliverOrders) {
        continue;
      }
      expect(Permissions.can(UserRole.admin, p), isTrue, reason: p.name);
    }
  });
}
