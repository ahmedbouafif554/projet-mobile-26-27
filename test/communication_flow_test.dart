import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/app_config.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/theme/theme_controller.dart';
import 'package:superfaster/features/communication/communication_routes.dart';
import 'package:superfaster/features/communication/models/chat_message.dart';
import 'package:superfaster/features/communication/presentation/controllers/notification_center_controller.dart';
import 'package:superfaster/features/communication/presentation/widgets/chat/message_bubble.dart';
import 'package:superfaster/features/communication/presentation/widgets/chat/typing_indicator.dart';
import 'package:superfaster/features/communication/presentation/widgets/notifications/notification_tile.dart';
import 'package:superfaster/features/communication/presentation/widgets/reviews/review_card.dart';
import 'package:superfaster/features/communication/presentation/widgets/reviews/star_rating.dart';
import 'package:superfaster/main.dart';

import 'test_helpers.dart';

/// Parcours « au doigt » du module 5 : messagerie, notifications et avis.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setUpAppTestEnvironment();
    AppConfig.mockLatency = const Duration(milliseconds: 100);
    AppConfig.mockServerDelay = const Duration(seconds: 2);
  });

  Future<void> settle(WidgetTester tester, [int ms = 900]) async {
    for (var t = 0; t <= ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, String location) async {
    await tester.pumpWidget(const SuperFasterApp());
    AppRouter.router.go(location);
    await settle(tester, 1200);
  }

  testWidgets(
    'chat : message rapide, statuts, « écrit… », réponse, modification, suppression',
    (tester) async {
      useScreenSize(tester, const Size(390, 844));
      ThemeController.instance.setMode(ThemeMode.light);
      final restoreErrors = ignoreOfflineImageErrors();

      await open(tester, CommunicationRoutes.chat('conv-support'));
      final before = tester.widgetList(find.byType(MessageBubble)).length;

      // Message rapide
      await tester.tap(find.text('Problème avec ma commande'));
      await tester.pump();
      expect(tester.widgetList(find.byType(MessageBubble)).length, before + 1);

      // Avec 100 ms de latence simulée : envoyé, distribué, lu, puis
      // l'interlocuteur écrit (≈ 400 ms)…
      await settle(tester, 450);
      expect(find.byType(TypingIndicator), findsOneWidget);
      // … et répond (≈ 700 ms).
      await settle(tester, 400);
      expect(find.byType(TypingIndicator), findsNothing);
      expect(tester.widgetList(find.byType(MessageBubble)).length, before + 2);
      final mine = tester
          .widgetList<MessageBubble>(find.byType(MessageBubble))
          .firstWhere((b) => b.message.text == 'Problème avec ma commande');
      expect(mine.message.status, MessageStatus.read);

      // Modification
      Finder inBubble(String text) => find.descendant(
        of: find.byType(MessageBubble),
        matching: find.text(text),
      );
      await tester.longPress(inBubble('Problème avec ma commande'));
      await settle(tester, 400);
      await tester.tap(find.text('Modifier'));
      await settle(tester, 400);
      await tester.enterText(
        find.byType(TextField).last,
        'Changer mon adresse de livraison',
      );
      await tester.tap(find.byIcon(Icons.check_rounded));
      await settle(tester, 400);
      expect(find.text('Changer mon adresse de livraison'), findsOneWidget);
      expect(find.textContaining('modifié'), findsOneWidget);

      // Suppression
      await tester.longPress(inBubble('Changer mon adresse de livraison'));
      await settle(tester, 400);
      await tester.tap(find.text('Supprimer'));
      await settle(tester, 400);
      expect(find.text('Message supprimé'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 1000);
      restoreErrors();
    },
  );

  testWidgets(
    'notifications : bannière push, tout lire, glisser pour supprimer + annuler',
    (tester) async {
      useScreenSize(tester, const Size(390, 844));
      final restoreErrors = ignoreOfflineImageErrors();
      final center = NotificationCenterController.instance;

      await open(tester, CommunicationRoutes.notifications);
      final count = tester.widgetList(find.byType(NotificationTile)).length;
      expect(count, greaterThan(0));

      // Notification push simulée : bannière animée en haut de l'écran.
      await tester.tap(find.byTooltip('Simuler une notification push'));
      await settle(tester, 500);
      expect(find.text('SuperFaster'), findsOneWidget);
      await settle(tester, 4500); // la bannière disparaît seule
      expect(find.text('SuperFaster'), findsNothing);

      // Tout marquer comme lu
      expect(center.unreadCount, greaterThan(0));
      await tester.tap(find.text('Tout marquer comme lu'));
      await settle(tester, 400);
      expect(center.unreadCount, 0);

      // Glisser pour supprimer, puis annuler
      final total = center.items.length;
      await tester.drag(
        find.byType(NotificationTile).first,
        const Offset(-500, 0),
      );
      await settle(tester, 600);
      expect(center.items.length, total - 1);
      await tester.tap(find.text('Annuler'));
      await settle(tester, 400);
      expect(center.items.length, total);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 4500);
      restoreErrors();
    },
  );

  testWidgets('avis : noter, commenter, publier puis voir sa carte', (
    tester,
  ) async {
    useScreenSize(tester, const Size(390, 844));
    final restoreErrors = ignoreOfflineImageErrors();

    await open(tester, CommunicationRoutes.restaurantReviews('r6'));
    expect(find.byType(ReviewCard), findsWidgets);

    await tester.tap(find.text('Donner mon avis'));
    await settle(tester, 1200);

    // Note globale : 4 étoiles (touche sur la 4e étoile)
    final stars = find.byType(AnimatedStarRating).first;
    final rect = tester.getRect(stars);
    await tester.tapAt(Offset(rect.left + rect.width * 0.7, rect.center.dy));
    await settle(tester, 600);
    expect(find.text('😊  Très bien'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Tacos savoureux, livraison rapide.',
    );
    await tester.tap(find.text('Publier mon avis'));
    await settle(tester, 3000); // envoi + animation de succès + retour

    expect(find.text('Tacos savoureux, livraison rapide.'), findsOneWidget);
    expect(find.text('En attente de validation'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 2500); // réponse simulée du restaurant
    restoreErrors();
  });
}
