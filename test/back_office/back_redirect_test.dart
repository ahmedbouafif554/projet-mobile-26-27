import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/back_office/router/back_redirect.dart';
import 'package:superfaster/back_office/router/back_routes.dart';
import 'package:superfaster/back_office/shell/back_nav.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/user.dart';

/// Règles d'accès du back office selon le rôle.
void main() {
  AuthState as(String userId) => AuthState(user: MockUsers.byId(userId));
  const guest = AuthState();
  final admin = as('u-admin');
  final resto = as('u-resto-1');

  test('non connecté : toujours vers la connexion', () {
    expect(backRedirect(guest, BackRoutes.dashboard), BackRoutes.login);
    expect(backRedirect(guest, BackRoutes.users), BackRoutes.login);
    expect(backRedirect(guest, BackRoutes.login), isNull);
  });

  test('client et livreur refusés (application mobile)', () {
    expect(backRedirect(as('u-client-1'), BackRoutes.dashboard), BackRoutes.login);
    expect(backRedirect(as('u-courier-1'), BackRoutes.orders), BackRoutes.login);
  });

  test('connecté : la connexion mène au tableau de bord', () {
    expect(backRedirect(admin, BackRoutes.login), BackRoutes.dashboard);
    expect(backRedirect(resto, '/'), BackRoutes.dashboard);
  });

  test("l'admin accède à tout sauf aux écrans restaurateur", () {
    for (final path in [
      BackRoutes.users,
      BackRoutes.user('u-client-1'),
      BackRoutes.restaurants,
      BackRoutes.categories,
      BackRoutes.products,
      BackRoutes.orders,
      BackRoutes.couriers,
      BackRoutes.deliveries,
      BackRoutes.map,
      BackRoutes.reviews,
      BackRoutes.campaigns,
      BackRoutes.chats,
      BackRoutes.account,
    ]) {
      expect(backRedirect(admin, path), isNull, reason: path);
    }
    expect(backRedirect(admin, BackRoutes.kitchen), BackRoutes.dashboard);
    expect(backRedirect(admin, BackRoutes.myRestaurant), BackRoutes.dashboard);
  });

  test('le restaurateur ne voit que son espace', () {
    for (final path in [
      BackRoutes.dashboard,
      BackRoutes.products,
      BackRoutes.myRestaurant,
      BackRoutes.orders,
      BackRoutes.kitchen,
      BackRoutes.reviews,
      BackRoutes.chats,
    ]) {
      expect(backRedirect(resto, path), isNull, reason: path);
    }
    for (final path in [
      BackRoutes.users,
      BackRoutes.restaurants,
      BackRoutes.categories,
      BackRoutes.couriers,
      BackRoutes.deliveries,
      BackRoutes.map,
      BackRoutes.campaigns,
    ]) {
      expect(backRedirect(resto, path), BackRoutes.dashboard, reason: path);
    }
  });

  test('chemin inconnu : tableau de bord', () {
    expect(backRedirect(admin, '/inconnu'), BackRoutes.dashboard);
  });

  test('menu filtré selon le rôle', () {
    List<String> labels(UserRole role) => [
      for (final g in navFor(role))
        for (final i in g.items) i.labelFor(role),
    ];
    expect(labels(UserRole.restaurant), [
      'Tableau de bord',
      'Mon menu',
      'Mon restaurant',
      'Commandes reçues',
      'Cuisine',
      'Avis',
      'Conversations',
    ]);
    expect(labels(UserRole.admin), contains('Utilisateurs'));
    expect(labels(UserRole.admin), isNot(contains('Cuisine')));
    expect(navGroupTitleFor(BackRoutes.order('o-1')), 'Commandes');
  });
}
