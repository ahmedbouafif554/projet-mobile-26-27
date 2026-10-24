import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_routes.dart';
import '../../features/catalog/catalog_routes.dart';
import '../../features/communication/communication_routes.dart';
import '../../features/delivery/delivery_routes.dart';
import '../../features/orders/orders_routes.dart';
import '../config/modules_config.dart';
import '../widgets/animated_branch_container.dart';
import '../widgets/main_shell.dart';
import 'module_routes.dart';

/// Configuration go_router de toute l'application, assemblée à partir de
/// [ModulesConfig.modules] : un onglet (branche) par module, ouvert sur
/// l'écran principal du module, avec ses autres écrans en sous-routes.
class AppRouter {
  AppRouter._();

  /// Routes déclarées par chaque module (un fichier par module).
  static final List<ModuleRoutes> moduleRoutes = [
    authRoutes,
    catalogRoutes,
    ordersRoutes,
    deliveryRoutes,
    communicationRoutes,
  ];

  /// Routes d'un module ; un module sans fichier de routes n'a que des placeholders.
  static ModuleRoutes routesOf(AppModule module) => moduleRoutes.firstWhere(
    (r) => r.moduleNumber == module.number,
    orElse: () => ModuleRoutes(moduleNumber: module.number),
  );

  /// Badges des onglets, par numéro de module.
  static final badges = {
    for (final routes in moduleRoutes)
      if (routes.badge != null) routes.moduleNumber: routes.badge!,
  };

  static final GoRouter router = _AppGoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ModulesConfig.initialRoute,
    // La racine (ex. : URL web sans chemin) relance l'application.
    redirect: (_, state) =>
        state.uri.path == '/' ? ModulesConfig.initialRoute : null,
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell, badges: badges),
        // Fondu entre onglets ; chaque onglet garde son état et son historique.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AnimatedBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          for (final module in ModulesConfig.modules)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: module.route,
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: routesOf(module).buildHome(context, state, module),
                  ),
                  routes: routesOf(module).routesFor(module),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// GoRouter de l'application, avec une seule différence : ouvrir un écran
/// d'onglet depuis une page plein écran (ex. : « Donner un avis » depuis le
/// suivi) referme les pages plein écran et affiche l'écran dans son onglet.
/// Un `push` classique créerait une seconde coque (clé de navigateur en
/// double) au-dessus de la page plein écran.
class _AppGoRouter extends GoRouter {
  _AppGoRouter({
    required List<RouteBase> routes,
    required GoRouterRedirect redirect,
    super.initialLocation,
    super.navigatorKey,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes, redirect: redirect),
         ),
       );

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    final current = routerDelegate.currentConfiguration.matches;
    final overShell = current.isNotEmpty && current.last is! ShellRouteMatch;
    final target = configuration.findMatch(Uri.parse(location), extra: extra);
    if (overShell && target.matches.lastOrNull is ShellRouteMatch) {
      go(location, extra: extra);
      return Future.value();
    }
    return super.push<T>(location, extra: extra);
  }
}
