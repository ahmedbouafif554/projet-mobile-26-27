import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/back_office/modules/catalog/catalog_controllers.dart';
import 'package:superfaster/back_office/modules/communication/communication_controllers.dart';
import 'package:superfaster/back_office/modules/delivery/delivery_controllers.dart';
import 'package:superfaster/back_office/modules/orders/orders_controller.dart';
import 'package:superfaster/back_office/modules/users/users_controller.dart';
import 'package:superfaster/back_office/router/back_routes.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/core/widgets/app_form.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/models.dart';

import '../test_helpers.dart';
import 'back_test_utils.dart';

/// Bouton plein (y compris `FilledButton.icon`) portant [label].
Finder filled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

/// Parcours du back office : connexion, gestion des données des 5 modules.
void main() {
  setUpAll(setUpAppTestEnvironment);

  late VoidCallback restore;
  setUp(() => restore = ignoreOfflineImageErrors());
  tearDown(() => restore());

  testWidgets('connexion admin démo puis déconnexion', (tester) async {
    final app = await pumpBack(tester);
    expect(app.path, BackRoutes.login);
    expect(find.text("Connexion à l'Espace Pro"), findsOneWidget);

    await tester.tap(find.text('Admin démo'));
    await settle(tester, 2500);
    expect(app.path, BackRoutes.dashboard);
    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Commandes du jour'), findsOneWidget);

    // Menu du compte → Déconnexion (avec confirmation).
    await tester.tap(find.text('Sophie').first);
    await settle(tester, 600);
    await tester.tap(find.text('Déconnexion').last);
    await settle(tester, 600);
    await tester.tap(filled('Déconnexion'));
    await settle(tester, 1500);
    expect(app.path, BackRoutes.login);
    await unmountBack(tester);
  });

  testWidgets("un client ne peut pas entrer dans l'Espace Pro", (tester) async {
    final app = await pumpBack(tester);
    await tester.enterText(find.byType(TextField).first, DemoAccounts.client);
    await tester.tap(find.text('Se connecter'));
    await settle(tester, 1500);
    expect(app.path, BackRoutes.login);
    expect(find.textContaining('réservé aux restaurants'), findsOneWidget);
    await unmountBack(tester);
  });

  testWidgets('restaurateur : menu et tableau de bord de son restaurant', (
    tester,
  ) async {
    final app = await pumpBack(tester);
    await tester.tap(find.text('Restaurant démo'));
    await settle(tester, 2500);
    expect(app.path, BackRoutes.dashboard);
    expect(find.text('Mon menu'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Utilisateurs'), findsNothing);
    expect(find.text('Panier moyen'), findsOneWidget);
    await unmountBack(tester);
  });

  testWidgets('utilisateurs : création puis blocage', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-admin',
      location: BackRoutes.users,
    );
    final before = app.read(usersControllerProvider).value!.length;

    await tester.tap(find.text('Nouvel utilisateur'));
    await settle(tester, 1000);
    final fields = find.descendant(
      of: find.byType(AppForm),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Nina');
    await tester.enterText(fields.at(1), 'Durand');
    await tester.enterText(fields.at(2), 'nina.durand@exemple.fr');
    await tester.enterText(fields.at(3), '06 12 34 56 78');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester, 1500);
    expect(app.read(usersControllerProvider).value!.length, before + 1);
    expect(find.text('Utilisateur créé'), findsOneWidget);

    await tapRowAction(tester, 'Nina Durand', 'Bloquer');
    await tester.tap(filled('Bloquer'));
    await settle(tester, 1200);
    final nina = app
        .read(usersControllerProvider)
        .value!
        .firstWhere((u) => u.email == 'nina.durand@exemple.fr');
    expect(nina.status, UserStatus.blocked);
    await unmountBack(tester);
  });

  testWidgets('restaurants : validation d’une demande', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-admin',
      location: BackRoutes.restaurants,
    );
    expect(find.text("Demandes d'inscription"), findsOneWidget);
    await tester.tap(find.text('Valider').first);
    await settle(tester, 1500);
    final validated = app
        .read(restaurantsControllerProvider)
        .value!
        .where((r) => r.status == RestaurantStatus.pending);
    expect(validated.length, 1);
    // Le compte du restaurateur est activé avec le restaurant.
    final owner = (await app.loaded(
      tester,
      usersControllerProvider,
    )).firstWhere((u) => u.id == 'u-resto-9');
    expect(owner.status, UserStatus.active);
    await unmountBack(tester);
  });

  testWidgets('produits : rupture depuis le tableau', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-resto-1',
      location: BackRoutes.products,
    );
    expect(find.text('Mon menu'), findsWidgets);
    await tester.tap(find.byType(Switch).first);
    await settle(tester, 1200);
    final products = app.read(productsControllerProvider).value!;
    expect(products.where((p) => !p.isAvailable), isNotEmpty);
    expect(products.every((p) => p.restaurantId == 'r1'), isTrue);
    await unmountBack(tester);
  });

  testWidgets('cuisine : accepter, démarrer, marquer prête', (tester) async {
    // Sakura Sushi (r3) a une nouvelle commande : #SF1074.
    final app = await pumpBack(
      tester,
      userId: 'u-resto-3',
      location: BackRoutes.kitchen,
    );
    Order order() => app
        .read(ordersControllerProvider)
        .value!
        .firstWhere((o) => o.reference == 'SF1074');
    expect(order().status, OrderStatus.pending);

    await tester.tap(filled('Accepter').first);
    await settle(tester, 1500);
    expect(order().status, OrderStatus.accepted);

    await tester.tap(filled('Démarrer').first);
    await settle(tester, 1500);
    expect(order().status, OrderStatus.preparing);

    await tester.tap(filled('Prête').first);
    await settle(tester, 1500);
    expect(order().status, OrderStatus.ready);
    // Une commande prête crée la course à assigner.
    final deliveries = await app.loaded(tester, deliveriesControllerProvider);
    expect(deliveries.any((d) => d.orderId == order().id), isTrue);
    await unmountBack(tester);
  });

  testWidgets('commande : passage à l’étape suivante depuis la fiche', (
    tester,
  ) async {
    final app = await pumpBack(
      tester,
      userId: 'u-admin',
      location: BackRoutes.order('o-1'),
    );
    final before = app
        .read(ordersControllerProvider)
        .value!
        .firstWhere((o) => o.id == 'o-1');
    await tester.tap(filled('Marquer prête'));
    await settle(tester, 1500);
    final after = app
        .read(ordersControllerProvider)
        .value!
        .firstWhere((o) => o.id == 'o-1');
    expect(before.status, OrderStatus.preparing);
    expect(after.status, OrderStatus.ready);
    expect(after.history.length, before.history.length + 1);
    await unmountBack(tester);
  });

  testWidgets('livraisons : assignation d’un livreur', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-admin',
      location: BackRoutes.deliveries,
    );
    final waiting = app
        .read(deliveriesControllerProvider)
        .value!
        .where((d) => d.status == DeliveryStatus.waiting)
        .length;
    await tester.tap(find.text('Assigner').first);
    await settle(tester, 1000);
    expect(find.textContaining('Assigner #'), findsOneWidget);
    await tester.tap(filled('Assigner').last);
    await settle(tester, 1500);
    final now = app
        .read(deliveriesControllerProvider)
        .value!
        .where((d) => d.status == DeliveryStatus.waiting)
        .length;
    expect(now, waiting - 1);
    await unmountBack(tester);
  });

  testWidgets('avis : publication par l’admin', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-admin',
      location: BackRoutes.reviews,
    );
    final pending = app
        .read(reviewsControllerProvider)
        .value!
        .where((r) => r.status == ReviewStatus.pending)
        .length;
    await tester.tap(filled('Publier').first);
    await settle(tester, 1500);
    expect(
      app
          .read(reviewsControllerProvider)
          .value!
          .where((r) => r.status == ReviewStatus.pending)
          .length,
      pending - 1,
    );
    await unmountBack(tester);
  });

  testWidgets('conversation : envoi et réponse automatique', (tester) async {
    final app = await pumpBack(
      tester,
      userId: 'u-resto-1',
      location: BackRoutes.chat('chat-1'),
    );
    expect(app.read(authServiceProvider).user!.id, 'u-resto-1');
    await tester.enterText(find.byType(TextField).last, 'Votre commande arrive !');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester, 800);
    expect(find.text('Votre commande arrive !'), findsWidgets);
    // Le client « écrit » puis répond.
    await settle(tester, 4500);
    final chat = app
        .read(chatsControllerProvider)
        .value!
        .firstWhere((c) => c.id == 'chat-1');
    expect(chat.lastMessage, isNot('Votre commande arrive !'));
    await unmountBack(tester);
  });
}
