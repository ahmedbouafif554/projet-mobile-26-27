import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/routing/safe_go_router.dart';
import '../../core/widgets/animated_branch_container.dart';
import '../modules/auth/auth_routes.dart';
import '../modules/auth/providers/onboarding_provider.dart';
import '../modules/catalog/catalog_routes.dart';
import '../modules/communication/communication_routes.dart';
import '../modules/courier/courier_routes.dart';
import '../modules/orders/orders_routes.dart';
import '../shell/front_shell.dart';
import '../shell/front_tabs.dart';
import 'front_redirect.dart';
import 'front_routes.dart';

/// Routeur du front office : parcours public, deux coques à onglets (client
/// et livreur) et pages du compte en plein écran. Il se réévalue à chaque
/// connexion / déconnexion (redirect selon le rôle).
final frontRouterProvider = Provider.autoDispose<GoRouter>((ref) {
  // Réévalue les redirections à la connexion, à la déconnexion ou au
  // changement de rôle — pas quand le profil est modifié (un rafraîchissement
  // relit l'URL et refermerait les pages ouvertes par-dessus).
  final authChanges = ValueNotifier(0);
  ref.listen(
    authServiceProvider.select((auth) => (auth.user?.id, auth.role)),
    (_, _) => authChanges.value++,
  );

  final router = SafeGoRouter(
    initialLocation: ref.read(onboardingSeenProvider)
        ? FrontRoutes.login
        : FrontRoutes.splash,
    refreshListenable: authChanges,
    redirect: (_, state) =>
        frontRedirect(ref.read(authServiceProvider), state.uri.path),
    routes: [
      ...authPublicRoutes(),
      _tabsShell(clientTabs),
      _tabsShell(courierTabs),
      ...accountRoutes(),
      ...catalogAccountRoutes(),
      ...orderFullScreenRoutes(),
      ...courierAccountRoutes(),
      ...communicationAccountRoutes(),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});

/// Une coque à onglets : chaque onglet garde son historique, fondu entre
/// onglets.
StatefulShellRoute _tabsShell(List<FrontTab> tabs) => StatefulShellRoute(
  builder: (context, state, navigationShell) =>
      FrontShell(navigationShell: navigationShell, tabs: tabs),
  navigatorContainerBuilder: (context, navigationShell, children) =>
      AnimatedBranchContainer(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
  branches: [
    for (final tab in tabs)
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: tab.path,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: tab.builder()),
            routes: tab.routes,
          ),
        ],
      ),
  ],
);
