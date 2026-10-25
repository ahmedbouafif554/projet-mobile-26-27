import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/back_office/router/back_routes.dart';
import 'package:superfaster/back_office/shell/bo_page.dart';

import '../test_helpers.dart';
import 'back_test_utils.dart';

/// Test de fumée : chaque page du back office s'affiche sans exception ni
/// débordement, pour l'admin et le restaurateur, sur grand écran, tablette
/// et téléphone, en clair et en sombre.
void main() {
  setUpAll(setUpAppTestEnvironment);

  const pages = <String?, List<String>>{
    null: [BackRoutes.login],
    'u-admin': [
      BackRoutes.dashboard,
      BackRoutes.users,
      '/users/u-client-1',
      '/users/u-resto-1',
      '/users/u-courier-1',
      BackRoutes.restaurants,
      '/restaurants/r1',
      '/restaurants/r9',
      BackRoutes.categories,
      BackRoutes.products,
      BackRoutes.orders,
      '/orders/o-1',
      '/orders/o-6',
      BackRoutes.couriers,
      '/couriers/c-1',
      '/couriers/c-6',
      BackRoutes.deliveries,
      BackRoutes.map,
      BackRoutes.reviews,
      BackRoutes.campaigns,
      BackRoutes.chats,
      '/chats?id=chat-4',
      BackRoutes.account,
    ],
    'u-resto-1': [
      BackRoutes.dashboard,
      BackRoutes.products,
      BackRoutes.myRestaurant,
      BackRoutes.orders,
      BackRoutes.kitchen,
      BackRoutes.reviews,
      '/chats?id=chat-1',
      BackRoutes.account,
    ],
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in const [Size(1440, 900), Size(820, 1000), Size(390, 844)]) {
      testWidgets('pages (${mode.name}, ${size.width.toInt()} px)', (
        tester,
      ) async {
        final restore = ignoreOfflineImageErrors();
        for (final entry in pages.entries) {
          for (final location in entry.value) {
            final app = await pumpBack(
              tester,
              userId: entry.key,
              location: location,
              size: size,
              mode: mode,
            );
            await settle(tester, 1500);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Exception sur $location',
            );
            expect(
              app.path,
              Uri.parse(location).path,
              reason: 'Redirection inattendue depuis $location',
            );
            if (entry.key != null) {
              expect(find.byType(BoPage), findsWidgets, reason: location);
            }
            await unmountBack(tester);
          }
        }
        restore();
      });
    }
  }
}
