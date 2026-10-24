import 'package:go_router/go_router.dart';

import '../../../core/routing/page_transitions.dart';
import '../../router/front_routes.dart';
import 'presentation/pages/chat_page.dart';
import 'presentation/pages/chats_list_page.dart';
import 'presentation/pages/my_reviews_page.dart';
import 'presentation/pages/notification_settings_page.dart';
import 'presentation/pages/notifications_page.dart';

/// Conversation ouverte depuis une liste (onglet Messages du livreur).
List<RouteBase> chatRoutes() => [
  transitionRoute(
    ':id',
    (_, state) => ChatPage(chatId: state.pathParameters['id']!),
  ),
];

/// Module 5 — écrans du compte (plein écran, client et livreur) : mes avis,
/// notifications et préférences, messages.
List<RouteBase> communicationAccountRoutes() => [
  transitionRoute(FrontRoutes.myReviews, (_, _) => const MyReviewsPage()),
  transitionRoute(
    FrontRoutes.notifications,
    (_, _) => const NotificationsPage(),
    routes: [
      transitionRoute(
        'settings',
        (_, _) => const NotificationSettingsPage(),
      ),
    ],
  ),
  transitionRoute(
    FrontRoutes.messages,
    (_, _) => const ChatsListPage(),
    routes: chatRoutes(),
  ),
];
