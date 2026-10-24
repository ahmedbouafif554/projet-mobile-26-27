import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/module_routes.dart';
import '../../core/routes/page_transitions.dart';
import 'presentation/controllers/conversations_controller.dart';
import 'presentation/pages/chat/chat_page.dart';
import 'presentation/pages/chat/conversations_page.dart';
import 'presentation/pages/notifications/notification_preferences_page.dart';
import 'presentation/pages/notifications/notifications_center_page.dart';
import 'presentation/pages/reviews/my_reviews_page.dart';
import 'presentation/pages/reviews/photo_viewer_page.dart';
import 'presentation/pages/reviews/restaurant_reviews_page.dart';
import 'presentation/pages/reviews/review_moderation_page.dart';
import 'presentation/pages/reviews/write_review_page.dart';

/// Chemins des écrans du module (avis, notifications, messagerie).
/// Toutes les routes du module commencent par `/communication`.
class CommunicationRoutes {
  CommunicationRoutes._();

  static const root = '/communication';

  // Notifications
  static const notifications = '$root/notifications';
  static const notificationSettings = '$root/notification-settings';

  // Messagerie
  static const chats = root; // écran principal de l'onglet Messages
  static String chat(String conversationId) => '$root/chat/$conversationId';

  // Avis
  static const reviews = '$root/reviews';
  static const myReviews = '$root/my-reviews';
  static const moderation = '$root/moderation';
  static const newReview = '$root/write-review';
  static const photos = '$root/photos';

  static String restaurantReviews(String restaurantId) =>
      '$reviews/$restaurantId';

  static String writeReview({required String restaurantId, String? orderId}) =>
      Uri(
        path: newReview,
        queryParameters: {
          'restaurantId': restaurantId,
          if (orderId != null) 'orderId': orderId,
        },
      ).toString();

  static String editReview(String reviewId) =>
      Uri(path: newReview, queryParameters: {'reviewId': reviewId}).toString();
}

/// Conversation, restaurant et commande de démo (cartes du module,
/// ouvertes sans identifiant).
const _demoConversation = 'conv-courier';
const _demoRestaurant = 'r3';
const _demoOrder = 'SF1045';

final _conversations = ConversationsController.instance;

/// Routes du Module 5 — Avis, notifications et messagerie
/// (`/communication/...`).
///
/// Identifiant d'écran (modules_config.dart) → vraie page.
/// Les écrans prévus absents de cette table affichent un placeholder.
final ModuleRoutes communicationRoutes = ModuleRoutes(
  moduleNumber: 5,
  screens: {
    'notifications': (_, _) => const NotificationsCenterPage(),
    'notification-settings': (_, _) => const NotificationPreferencesPage(),
    'conversations': (_, _) => const ConversationsPage(),
    'chat': (_, _) => const ChatPage(conversationId: _demoConversation),
    'reviews': (_, _) =>
        const RestaurantReviewsPage(restaurantId: _demoRestaurant),
    'my-reviews': (_, _) => const MyReviewsPage(),
    // Nouvel avis (?restaurantId=&orderId=) ou modification (?reviewId=).
    'write-review': (_, state) {
      final query = state.uri.queryParameters;
      // Ouvert sans paramètre (carte du module) : commande de démo.
      final demo = query.isEmpty;
      return WriteReviewPage(
        reviewId: query['reviewId'],
        restaurantId: query['restaurantId'] ?? (demo ? _demoRestaurant : null),
        orderId: query['orderId'] ?? (demo ? _demoOrder : null),
      );
    },
    'moderation': (_, _) => const ReviewModerationPage(),
  },
  transitions: {
    'chat': PageTransitionType.slide,
    'write-review': PageTransitionType.slideUp,
    'moderation': PageTransitionType.scale,
  },
  extraRoutes: [
    ModuleRoutes.route(
      'chat/:conversationId',
      (_, state) =>
          ChatPage(conversationId: state.pathParameters['conversationId']!),
      fullScreen: true,
      transition: PageTransitionType.slide,
    ),
    ModuleRoutes.route(
      'reviews/:restaurantId',
      (_, state) => RestaurantReviewsPage(
        restaurantId: state.pathParameters['restaurantId']!,
      ),
    ),
    // Visionneuse photo : fond transparent pendant le vol Hero.
    GoRoute(
      path: 'photos',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 350),
        child: PhotoViewerPage(args: state.extra as PhotoViewerArgs?),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
  ],
  // Badge de l'onglet : messages non lus.
  badge: TabBadge(
    listenable: _conversations,
    count: () => _conversations.totalUnread,
  ),
);
