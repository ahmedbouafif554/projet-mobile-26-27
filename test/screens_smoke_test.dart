import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/modules_config.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/routes/app_routes.dart';
import 'package:superfaster/core/session/app_session.dart';
import 'package:superfaster/core/theme/theme_controller.dart';
import 'package:superfaster/features/catalog/data/catalog_mock_data.dart';
import 'package:superfaster/features/communication/communication_routes.dart';
import 'package:superfaster/features/orders/models/cart_item.dart';
import 'package:superfaster/features/orders/presentation/controllers/cart_controller.dart';
import 'package:superfaster/main.dart';

import 'test_helpers.dart';

/// Test de fumée : chaque écran s'affiche sans exception ni débordement,
/// sur un petit et un grand téléphone, en mode clair et sombre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpAppTestEnvironment);

  final routes = [
    // Tous les écrans prévus (vrais écrans ou placeholders), générés depuis
    // modules_config.dart ; l'écran principal est sur la route du module.
    for (final module in ModulesConfig.modules)
      for (final screen in module.screens) module.routeOf(screen.id),
    // Écrans avec paramètres
    AppRoutes.otpFor('0612345678'),
    AppRoutes.restaurantsWith(category: 'courses'),
    AppRoutes.restaurantsWith(filter: 'popular'),
    AppRoutes.restaurantDetail('r1'),
    AppRoutes.restaurantDetail('r8'),
    AppRoutes.productDetail('r1-classic'),
    AppRoutes.productDetail('r8-fruits'),
    AppRoutes.confirmationOf('SF1046'),
    AppRoutes.trackingOf('SF1046'),
    AppRoutes.trackingOf('SF1045'),
    AppRoutes.trackingOf('SF1031'),
    CommunicationRoutes.chat('conv-courier'),
    CommunicationRoutes.chat('conv-r5'),
    CommunicationRoutes.restaurantReviews('r1'),
    CommunicationRoutes.restaurantReviews('r3'),
    CommunicationRoutes.writeReview(restaurantId: 'r3', orderId: 'SF1045'),
    CommunicationRoutes.editReview('rev-me-1'),
  ];

  const sizes = {'petit': Size(320, 640), 'grand': Size(412, 915)};

  Future<void> showRoute(WidgetTester tester, String location) async {
    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(location);
    await tester.pump();
    // Laisse passer transitions, shimmer et chargements simulés.
    await tester.pump(const Duration(seconds: 2));
    // Cascades d'apparition lancées après le chargement (délais flutter_animate).
    await tester.pump(const Duration(seconds: 1));
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
        AppSession.instance.login();
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
        await showRoute(tester, AppRoutes.cart);
        await showRoute(tester, AppRoutes.checkout);
        await showRoute(tester, AppRoutes.restaurantDetail('r1'));
        CartController.instance.clear();

        restoreErrors();
      });
    }
  }
}
