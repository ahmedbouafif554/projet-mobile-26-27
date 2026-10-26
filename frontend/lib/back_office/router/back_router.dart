import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/routing/page_transitions.dart';
import '../../core/routing/safe_go_router.dart';
import '../account/account_page.dart';
import '../auth/back_login_page.dart';
import '../dashboard/dashboard_page.dart';
import '../modules/catalog/catalog_routes.dart';
import '../modules/communication/communication_routes.dart';
import '../modules/delivery/delivery_routes.dart';
import '../modules/orders/orders_routes.dart';
import '../modules/users/user_detail_page.dart';
import '../modules/users/users_page.dart';
import '../shell/back_shell.dart';
import 'back_redirect.dart';
import 'back_routes.dart';
import 'bo_route.dart';

/// Routeur du back office : connexion, puis toutes les pages dans la coque
/// (sidebar + topbar). Les accès dépendent du rôle (voir back_redirect).
final backRouterProvider = Provider.autoDispose<GoRouter>((ref) {
  // Réévalue les redirections à la connexion / déconnexion uniquement.
  final authChanges = ValueNotifier(0);
  ref.listen(
    authServiceProvider.select((auth) => (auth.user?.id, auth.role)),
    (_, _) => authChanges.value++,
  );

  final router = SafeGoRouter(
    initialLocation: BackRoutes.dashboard,
    refreshListenable: authChanges,
    redirect: (_, state) =>
        backRedirect(ref.read(authServiceProvider), state.uri.path),
    routes: [
      transitionRoute(
        BackRoutes.login,
        (_, _) => const BackLoginPage(),
        type: PageTransitionType.fade,
      ),
      ShellRoute(
        builder: (context, state, child) =>
            BackShell(location: state.uri.path, child: child),
        routes: [
          boRoute(BackRoutes.dashboard, (_, _) => const DashboardPage()),
          boRoute(BackRoutes.account, (_, _) => const AccountPage()),
          boRoute(
            BackRoutes.users,
            (_, _) => const UsersPage(),
            routes: [
              boRoute(
                ':id',
                (_, state) =>
                    UserDetailPage(userId: state.pathParameters['id']!),
              ),
            ],
          ),
          ...catalogRoutes(),
          ...ordersRoutes(),
          ...deliveryRoutes(),
          ...communicationRoutes(),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});
