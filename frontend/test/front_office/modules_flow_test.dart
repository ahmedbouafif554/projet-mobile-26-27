import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/front_office/modules/auth/providers/addresses_controller.dart';
import 'package:superfaster/front_office/modules/catalog/providers/catalog_providers.dart';
import 'package:superfaster/front_office/modules/communication/providers/communication_providers.dart';
import 'package:superfaster/front_office/modules/courier/providers/courier_providers.dart';
import 'package:superfaster/front_office/modules/orders/providers/cart_controller.dart';
import 'package:superfaster/front_office/modules/orders/providers/orders_providers.dart';
import 'package:superfaster/front_office/modules/catalog/presentation/pages/restaurant_page.dart';
import 'package:superfaster/front_office/modules/communication/presentation/pages/write_review_page.dart';
import 'package:superfaster/front_office/modules/orders/presentation/pages/order_detail_page.dart';
import 'package:superfaster/front_office/router/front_routes.dart';
import 'package:superfaster/shared/models/models.dart';

import '../test_helpers.dart';
import 'front_test_utils.dart';

/// Valeur chargée d'un fournisseur asynchrone : on écoute et on fait avancer
/// le temps (les délais mock ne s'écoulent qu'avec des images).
Future<T> loaded<T>(
  WidgetTester tester,
  FrontHarness app,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = app.container.listen(provider, (_, _) {});
  await settle(tester, 300);
  final value = sub.read().value as T;
  sub.close();
  return value;
}

/// Bouton plein portant [label] (y compris `FilledButton.icon`).
Finder filled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

/// testWidgets qui ignore les photos non chargées (hors réseau).
void frontTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      final restore = ignoreOfflineImageErrors();
      try {
        await body(tester);
      } finally {
        restore();
      }
    });

/// Parcours des modules 2 à 5 du front office.
void main() {
  setUpAll(setUpAppTestEnvironment);

  frontTest('catalogue → panier → paiement → confirmation', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.restaurant('r1'),
    );
    expect(find.text('Burger Factory'), findsWidgets);

    // Fiche du plat puis ajout au panier.
    // Le plat du menu (et non la carte « Les plus commandés »).
    await scrollTo(tester, find.text('Double Bacon').last, RestaurantPage);
    await tester.tap(find.text('Double Bacon').last);
    await settle(tester, 800);
    await tester.tap(find.text('Ajouter'));
    await settle(tester, 1200);
    final cart = await loaded(tester, app, cartProvider);
    expect(cart.length, 1);
    expect(cart.first.product.name, 'Double Bacon');
    expect(find.text('Voir le panier'), findsOneWidget);

    // Panier → paiement avec un code promo (après le snackbar d'ajout).
    await settle(tester, 4500);
    app.go(FrontRoutes.cart);
    await settle(tester, 1200);
    expect(find.text('Mon panier'), findsOneWidget);
    await tester.tap(find.text('Commander'));
    await settle(tester, 1200);
    expect(app.path, FrontRoutes.checkout);
    await tester.enterText(find.byType(TextField).first, 'SUPER10');
    await tester.tap(find.text('Appliquer'));
    await settle(tester, 800);
    expect(find.textContaining('Code SUPER10'), findsWidgets);

    // Le bouton de paiement est fixé en bas (le snackbar du code s'efface).
    await settle(tester, 4500);
    await tester.tap(find.textContaining('Payer'));
    await settle(tester, 3000);
    expect(app.path, startsWith('/order-confirmed/'));
    expect(find.text('Commande confirmée !'), findsOneWidget);
    final orders = await loaded(tester, app, myOrdersProvider);
    expect(orders.first.promoCode, 'SUPER10');
    expect(orders.first.status, OrderStatus.pending);
    expect(await loaded(tester, app, cartProvider), isEmpty);
    await unmountFront(tester);
  });

  frontTest('favoris : ajout puis liste', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.restaurant('r2'),
    );
    final before = await loaded(tester, app, favoritesProvider);
    expect(before.contains('r2'), isFalse);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await settle(tester, 800);
    expect((await loaded(tester, app, favoritesProvider)).contains('r2'), isTrue);

    app.go(FrontRoutes.favorites);
    await settle(tester, 1200);
    expect(find.text('Pizza Napoli'), findsOneWidget);
    await unmountFront(tester);
  });

  frontTest('recherche : restaurants et plats', (tester) async {
    await pumpFront(tester, userId: 'u-client-1', location: FrontRoutes.search);
    await tester.enterText(find.byType(TextField).first, 'sushi');
    await settle(tester, 1200);
    expect(find.text('Sakura Sushi'), findsWidgets);
    await unmountFront(tester);
  });

  frontTest('commande : annulation par le client', (tester) async {
    final app = await pumpFront(tester, userId: 'u-client-1');
    // Commande en attente créée directement (panier + paiement testés plus haut).
    final product = (await loaded(
      tester,
      app,
      restaurantProductsProvider('r1'),
    )).first;
    // Les délais mock ne s'écoulent qu'avec des images : on lance l'action,
    // on avance le temps, puis on lit le résultat.
    final adding = app.container.read(cartProvider.notifier).add(product);
    await settle(tester, 300);
    await adding;
    final address = (await loaded(tester, app, addressesProvider)).first;
    final placing = app.container
        .read(myOrdersProvider.notifier)
        .place(address: address, paymentMethod: PaymentMethod.card);
    await settle(tester, 600);
    final order = await placing;

    app.go(FrontRoutes.order(order.id));
    await settle(tester, 1500);
    await scrollTo(tester, find.text('Annuler'), OrderDetailPage);
    await tester.tap(find.text('Annuler'));
    await settle(tester, 800);
    await tester.tap(filled('Annuler la commande'));
    await settle(tester, 1200);
    final updated = (await loaded(
      tester,
      app,
      myOrdersProvider,
    )).firstWhere((o) => o.id == order.id);
    expect(updated.status, OrderStatus.cancelled);
    await unmountFront(tester);
  });

  frontTest('avis : noter une commande livrée', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.writeReview('o-13'),
    );
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(4));
    await settle(tester, 600);
    expect(find.text('Excellent ! 🤩'), findsOneWidget);
    await scrollTo(tester, find.text('Publier mon avis'), WriteReviewPage);
    await tester.tap(find.text('Publier mon avis'));
    await settle(tester, 1500);
    final mine = await loaded(tester, app, myReviewsProvider);
    final review = mine.firstWhere((r) => r.orderId == 'o-13');
    expect(review.rating, 5);
    expect(review.status, ReviewStatus.pending);
    await unmountFront(tester);
  });

  frontTest('notifications : tout marquer comme lu', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.notifications,
    );
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
    await tester.tap(find.text('Tout marquer comme lu'));
    await settle(tester, 800);
    final list = await loaded(tester, app, notificationsProvider);
    expect(list.every((n) => n.isRead), isTrue);
    expect(find.text('Tout marquer comme lu'), findsNothing);
    await unmountFront(tester);
  });

  frontTest('messages : envoi puis réponse automatique', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.chat('chat-1'),
    );
    await tester.enterText(find.byType(TextField).last, 'Merci beaucoup !');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester, 800);
    expect(find.text('Merci beaucoup !'), findsWidgets);
    await settle(tester, 4500);
    final chats = await loaded(tester, app, myChatsProvider);
    expect(
      chats.firstWhere((c) => c.id == 'chat-1').lastMessage,
      isNot('Merci beaucoup !'),
    );
    await unmountFront(tester);
  });

  frontTest('livreur : terminer la course puis en accepter une autre', (
    tester,
  ) async {
    final app = await pumpFront(
      tester,
      userId: 'u-courier-1',
      location: FrontRoutes.courierDeliveries,
    );
    // Karim (c-1) a une course en route : #SF1071.
    final current = (await loaded(
      tester,
      app,
      myDeliveriesProvider,
    )).firstWhere((d) => d.status.isActive);
    expect(current.status, DeliveryStatus.inTransit);
    await tester.tap(find.textContaining('En cours ('));
    await settle(tester, 800);
    await tester.tap(find.text('Commande livrée').first);
    await settle(tester, 1500);
    final courier = await loaded(tester, app, myCourierProvider);
    expect(courier!.status, CourierStatus.available);

    // Une course proposée est acceptée.
    final offers = await loaded(tester, app, availableDeliveriesProvider);
    expect(offers, isNotEmpty);
    await tester.tap(find.text('Offres (${offers.length})'));
    await settle(tester, 800);
    await tester.tap(find.text('Accepter').first);
    await settle(tester, 1500);
    final after = await loaded(tester, app, myCourierProvider);
    expect(after!.status, CourierStatus.busy);
    await unmountFront(tester);
  });

  frontTest('livreur : passer hors ligne', (tester) async {
    final app = await pumpFront(
      tester,
      userId: 'u-courier-3',
      location: FrontRoutes.courierDashboard,
    );
    final courier = await loaded(tester, app, myCourierProvider);
    final wasOnline = courier!.status.isOnline;
    await tester.tap(find.byType(Switch).first);
    await settle(tester, 1000);
    final after = await loaded(tester, app, myCourierProvider);
    expect(after!.status.isOnline, !wasOnline);
    await unmountFront(tester);
  });
}
