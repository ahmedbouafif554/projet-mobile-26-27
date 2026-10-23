import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/theme/theme_controller.dart';
import 'package:superfaster/features/catalog/data/catalog_mock_data.dart';
import 'package:superfaster/features/orders/models/cart_item.dart';
import 'package:superfaster/features/orders/presentation/controllers/cart_controller.dart';
import 'package:superfaster/main.dart';

import 'test_helpers.dart';

/// Test de fumée : chaque écran s'affiche sans exception ni débordement,
/// sur un petit et un grand téléphone, en mode clair et sombre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpAppTestEnvironment);

  const routes = [
    '/',
    '/onboarding',
    '/login',
    '/register',
    '/otp?phone=0612345678',
    '/forgot-password',
    '/home',
    '/search',
    '/orders',
    '/profile',
    '/restaurants',
    '/restaurants?category=courses',
    '/restaurants?filter=popular',
    '/restaurant/r1?hero=list',
    '/restaurant/r8?hero=list',
    '/product/r1-classic?hero=menu',
    '/product/r8-fruits?hero=menu',
    '/favorites',
    '/cart',
    '/checkout',
    '/order-confirmation/SF1046',
    '/tracking/SF1046',
    '/tracking/SF1045',
    '/tracking/SF1031',
    '/parcel',
    '/edit-profile',
    '/addresses',
    '/payment-methods',
    '/notification-settings',
    '/language',
    '/notifications',
    '/admin',
  ];

  const sizes = {'petit': Size(320, 640), 'grand': Size(412, 915)};

  Future<void> showRoute(WidgetTester tester, String location) async {
    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(location);
    await tester.pump();
    // Laisse passer transitions, shimmer et chargements simulés.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull, reason: 'Exception sur $location');
    // Démonte l'arbre : annule les minuteurs encore actifs.
    await tester.pumpWidget(const SizedBox());
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in sizes.entries) {
      testWidgets('tous les écrans (${mode.name}, ${size.key} écran)', (
        tester,
      ) async {
        useScreenSize(tester, size.value);
        ThemeController.instance.setMode(mode);
        final restoreErrors = ignoreOfflineImageErrors();

        for (final route in routes) {
          await showRoute(tester, route);
        }

        // Panier et validation avec des articles.
        CartController.instance
          ..add(
            CartItem.withDefaults(CatalogMockData.productById('r1-classic')),
          )
          ..add(
            CartItem(
              product: CatalogMockData.productById('r1-fries'),
              quantity: 2,
            ),
          )
          ..applyPromo('BIENVENUE30');
        await showRoute(tester, '/cart');
        await showRoute(tester, '/checkout');
        await showRoute(tester, '/restaurant/r1?hero=list');
        CartController.instance.clear();

        restoreErrors();
      });
    }
  }
}
