import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// GoRouter des deux applications, avec une seule différence : ouvrir un
/// écran d'onglet (dans un StatefulShellRoute) depuis une page plein écran
/// referme les pages plein écran et affiche l'écran dans son onglet.
///
/// Un `push` classique de go_router créerait une seconde coque au-dessus de
/// la page plein écran (clé de navigateur en double → erreur).
class SafeGoRouter extends GoRouter {
  SafeGoRouter({
    required List<RouteBase> routes,
    GoRouterRedirect? redirect,
    super.initialLocation,
    super.navigatorKey,
    super.refreshListenable,
    super.debugLogDiagnostics,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes, redirect: redirect ?? (_, _) => null),
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
