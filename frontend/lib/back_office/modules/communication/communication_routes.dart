import 'package:go_router/go_router.dart';

import '../../router/back_routes.dart';
import '../../router/bo_route.dart';
import 'campaigns_page.dart';
import 'chats_page.dart';
import 'reviews_page.dart';

/// Routes du Module 5 (communication). La conversation ouverte est un
/// paramètre de la page (`/chats?id=…`) : la liste garde son état.
List<RouteBase> communicationRoutes() => [
  boRoute(BackRoutes.reviews, (_, _) => const ReviewsPage()),
  boRoute(BackRoutes.campaigns, (_, _) => const CampaignsPage()),
  boRoute(
    BackRoutes.chats,
    (_, state) => ChatsPage(chatId: state.uri.queryParameters['id']),
  ),
];
