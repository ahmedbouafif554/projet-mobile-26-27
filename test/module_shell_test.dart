import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/modules_config.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/routes/app_routes.dart';
import 'package:superfaster/core/session/app_session.dart';
import 'package:superfaster/core/theme/theme_controller.dart';
import 'package:superfaster/features/catalog/data/catalog_mock_data.dart';
import 'package:superfaster/features/catalog/presentation/pages/home_page.dart';
import 'package:superfaster/features/communication/communication_routes.dart';
import 'package:superfaster/features/communication/presentation/pages/chat/chat_page.dart';
import 'package:superfaster/features/communication/presentation/pages/chat/conversations_page.dart';
import 'package:superfaster/features/communication/presentation/pages/reviews/write_review_page.dart';
import 'package:superfaster/features/delivery/presentation/pages/parcel_page.dart';
import 'package:superfaster/features/orders/models/cart_item.dart';
import 'package:superfaster/features/orders/presentation/controllers/cart_controller.dart';
import 'package:superfaster/features/orders/presentation/pages/orders_page.dart';
import 'package:superfaster/features/profile/presentation/pages/profile_page.dart';
import 'package:superfaster/main.dart';

import 'test_helpers.dart';

/// Coque de l'application : démarrage, barre des 5 modules, badges,
/// écrans plein écran et placeholders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpAppTestEnvironment);

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var t = 0; t <= ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder inNavBar(String text) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(text),
  );

  setUp(() {
    ThemeController.instance.setMode(ThemeMode.light);
    CartController.instance.clear();
  });

  testWidgets('splash → onboarding → connexion → accueil', (tester) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();
    AppSession.instance.logout();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(ModulesConfig.initialRoute);
    await settle(tester, 300);
    expect(find.byType(NavigationBar), findsNothing, reason: 'plein écran');

    // Le splash enchaîne seul sur l'onboarding.
    await settle(tester, 3500);
    await tester.tap(find.text('Passer'));
    await settle(tester);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Se connecter'));
    // Connexion simulée, puis chargement et cascades de l'accueil.
    await settle(tester, 4000);

    // Une destination par module, onglet « Explorer » ouvert sur l'accueil.
    expect(
      find.byType(NavigationDestination),
      findsNWidgets(ModulesConfig.modules.length),
    );
    expect(find.byType(HomePage), findsOneWidget);
    expect(AppSession.instance.isLoggedIn, isTrue);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    restoreErrors();
  });

  testWidgets('chaque onglet s\'ouvre sur son écran, sans bouton retour', (
    tester,
  ) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(ModulesConfig.homeRoute);
    await settle(tester, 1500);

    const tabs = {
      'Compte': ProfilePage,
      'Explorer': HomePage,
      'Commandes': OrdersPage,
      'Livraison': ParcelPage,
      'Messages': ConversationsPage,
    };
    for (final tab in tabs.entries) {
      await tester.tap(inNavBar(tab.key));
      await settle(tester, 1500);
      expect(find.byType(tab.value), findsOneWidget, reason: tab.key);
      expect(find.byTooltip('Retour'), findsNothing, reason: tab.key);
    }

    // La recherche s'ouvre depuis l'accueil, avec un bouton retour.
    await tester.tap(inNavBar('Explorer'));
    await settle(tester);
    AppRouter.router.push(AppRoutes.search);
    await settle(tester);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    restoreErrors();
  });

  testWidgets('badge animé du panier sur l\'onglet Commandes', (tester) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(ModulesConfig.homeRoute);
    await settle(tester, 1500);

    expect(inNavBar('2'), findsNothing);
    CartController.instance.add(
      CartItem(product: CatalogMockData.productById('r1-fries'), quantity: 2),
    );
    await settle(tester);
    expect(inNavBar('2'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    restoreErrors();
  });

  testWidgets('plein écran sans barre, et retour à un onglet sans erreur', (
    tester,
  ) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(CommunicationRoutes.chats);
    await settle(tester, 1500);

    // Le chat s'ouvre par-dessus la barre de navigation.
    AppRouter.router.push(CommunicationRoutes.chat('conv-courier'));
    await settle(tester, 1500);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    AppRouter.router.pop();
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Depuis le suivi (plein écran), le formulaire d'avis (écran d'onglet)
    // s'ouvre dans l'onglet Messages, sans seconde barre de navigation.
    AppRouter.router.go(AppRoutes.trackingOf('SF1045'));
    await settle(tester, 1500);
    expect(find.byType(NavigationBar), findsNothing);
    AppRouter.router.push(
      CommunicationRoutes.writeReview(restaurantId: 'r3', orderId: 'SF1045'),
    );
    await settle(tester, 1500);
    expect(find.byType(WriteReviewPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    restoreErrors();
  });

  testWidgets('un écran prévu non développé affiche son placeholder', (
    tester,
  ) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(ModulesConfig.byNumber(3).routeOf('order-detail'));
    await settle(tester);
    expect(
      find.text('En cours de développement par le Module 3'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await settle(tester, 1500);
    expect(find.byType(OrdersPage), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 500);
    restoreErrors();
  });
}
