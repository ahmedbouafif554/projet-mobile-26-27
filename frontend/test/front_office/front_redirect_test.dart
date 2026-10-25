import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/front_office/router/front_redirect.dart';
import 'package:superfaster/front_office/router/front_routes.dart';
import 'package:superfaster/shared/mock/mock_users.dart';

void main() {
  const guest = AuthState();
  final client = AuthState(user: MockUsers.byId('u-client-1'));
  final courier = AuthState(user: MockUsers.byId('u-courier-1'));
  final admin = AuthState(user: MockUsers.byId('u-admin'));

  test('non connecté : seules les pages publiques', () {
    expect(frontRedirect(guest, FrontRoutes.splash), isNull);
    expect(frontRedirect(guest, FrontRoutes.login), isNull);
    expect(frontRedirect(guest, FrontRoutes.otp), isNull);
    expect(frontRedirect(guest, FrontRoutes.explore), FrontRoutes.login);
    expect(frontRedirect(guest, FrontRoutes.settings), FrontRoutes.login);
    expect(
      frontRedirect(guest, FrontRoutes.courierDashboard),
      FrontRoutes.login,
    );
  });

  test('connecté : les pages publiques renvoient à l\'accueil du rôle', () {
    expect(frontRedirect(client, FrontRoutes.login), FrontRoutes.explore);
    expect(
      frontRedirect(courier, FrontRoutes.register),
      FrontRoutes.courierDashboard,
    );
    expect(frontRedirect(client, FrontRoutes.splash), isNull);
  });

  test('chaque rôle reste dans son espace', () {
    expect(frontRedirect(client, FrontRoutes.cart), isNull);
    expect(frontRedirect(client, FrontRoutes.addresses), isNull);
    expect(
      frontRedirect(client, FrontRoutes.courierEarnings),
      FrontRoutes.explore,
    );

    expect(frontRedirect(courier, FrontRoutes.courierEarnings), isNull);
    expect(frontRedirect(courier, FrontRoutes.settings), isNull);
    expect(
      frontRedirect(courier, FrontRoutes.explore),
      FrontRoutes.courierDashboard,
    );
    expect(
      frontRedirect(courier, '/couriers-ne-pas-confondre'),
      FrontRoutes.courierDashboard,
    );
  });

  test('un compte du back office n\'a pas accès à l\'application', () {
    expect(frontRedirect(admin, FrontRoutes.explore), FrontRoutes.login);
    expect(frontRedirect(admin, FrontRoutes.login), isNull);
  });
}
