import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/routes/app_routes.dart';
import 'package:superfaster/core/theme/theme_controller.dart';
import 'package:superfaster/core/widgets/selectable_chip.dart';
import 'package:superfaster/features/catalog/presentation/pages/product_page.dart';
import 'package:superfaster/features/catalog/presentation/pages/restaurant_page.dart';
import 'package:superfaster/features/catalog/presentation/widgets/product_tile.dart';
import 'package:superfaster/features/catalog/presentation/widgets/restaurant_card.dart';
import 'package:superfaster/features/delivery/presentation/pages/tracking_page.dart';
import 'package:superfaster/features/orders/presentation/controllers/cart_controller.dart';
import 'package:superfaster/features/orders/presentation/pages/cart_page.dart';
import 'package:superfaster/features/orders/presentation/pages/checkout_page.dart';
import 'package:superfaster/features/orders/presentation/pages/order_confirmation_page.dart';
import 'package:superfaster/features/orders/presentation/pages/orders_page.dart';
import 'package:superfaster/features/profile/presentation/pages/profile_page.dart';
import 'package:superfaster/main.dart';

import 'test_helpers.dart';

/// Parcours complet « au doigt » : vérifie la navigation, les animations
/// Hero (aucun tag en double) et le panier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpAppTestEnvironment);

  /// Fait défiler jusqu'à l'élément (centré) puis le touche.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder);
  }

  /// Laisse jouer une transition de page.
  /// On simule une image toutes les 50 ms pour que les animations
  /// enchaînées (pop automatique, glissements) s'exécutent réellement.
  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var t = 0; t <= ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('accueil → restaurant → produit → panier → commande → suivi', (
    tester,
  ) async {
    useScreenSize(tester, const Size(390, 844));
    ThemeController.instance.setMode(ThemeMode.light);
    final restoreErrors = ignoreOfflineImageErrors();
    CartController.instance.clear();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(AppRoutes.home);
    await settle(tester, 2000);

    // Restaurant populaire (animation Hero de l'image)
    await tapVisible(tester, find.byType(RestaurantCard).first);
    await settle(tester);
    expect(find.byType(RestaurantPage), findsOneWidget);

    // Ajout rapide « + » depuis le menu
    await tapVisible(tester, find.byType(QuickAddButton).first);
    await settle(tester, 300);
    expect(CartController.instance.itemCount, 1);
    CartController.instance.clear();
    await settle(tester, 300);

    // Produit (Hero de la photo du plat)
    await tapVisible(tester, find.byType(ProductTile).first);
    await settle(tester);
    expect(find.byType(ProductPage), findsOneWidget);

    // Ajout au panier : animation puis retour automatique au menu
    await tester.tap(find.text('Ajouter'));
    await settle(tester, 2000);
    expect(CartController.instance.itemCount, 1);
    expect(find.byType(RestaurantPage), findsOneWidget);

    // Barre « Voir le panier »
    await tester.tap(find.text('Voir le panier'));
    await settle(tester);
    expect(find.byType(CartPage), findsOneWidget);

    await tester.tap(find.text('Commander'));
    await settle(tester);
    expect(find.byType(CheckoutPage), findsOneWidget);

    // Paiement simulé puis confirmation (Lottie)
    await tester.tap(find.text('Confirmer et payer'));
    await settle(tester, 2500);
    expect(find.byType(OrderConfirmationPage), findsOneWidget);
    expect(CartController.instance.isEmpty, isTrue);

    // Suivi : les étapes avancent toutes seules
    await tester.tap(find.text('Suivre ma commande'));
    await settle(tester);
    expect(find.byType(TrackingPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('En préparation'), findsWidgets);

    // Retour : la page de suivi ramène à l'onglet Commandes
    await tester.tap(find.byTooltip('Retour'));
    await settle(tester);
    expect(find.byType(OrdersPage), findsOneWidget);

    // Changement d'onglet via la barre du bas
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Compte'),
      ),
    );
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    restoreErrors();
  });

  testWidgets('la catégorie présélectionnée défile en vue', (tester) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(AppRoutes.restaurantsWith(category: 'courses'));
    // L'accueil (sous la liste) finit aussi son chargement et ses cascades.
    await settle(tester, 2500);

    // La puce « Courses » (dernière de la liste) doit être dans l'écran.
    final chip = tester.getRect(find.widgetWithText(SelectableChip, 'Courses'));
    expect(chip.left, greaterThanOrEqualTo(0));
    expect(chip.right, lessThanOrEqualTo(390));

    await tester.pumpWidget(const SizedBox());
    restoreErrors();
  });
}
