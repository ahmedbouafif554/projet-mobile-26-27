import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../config/modules_config.dart';
import '../widgets/placeholder_page.dart';
import 'page_transitions.dart';

/// Navigateur racine : les écrans « plein écran » s'y ouvrent,
/// par-dessus la barre de navigation.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Construit un vrai écran à partir de la route courante.
typedef ScreenBuilder =
    Widget Function(BuildContext context, GoRouterState state);

/// Compteur affiché sur l'onglet d'un module, lu dans un contrôleur existant.
class TabBadge {
  const TabBadge({required this.listenable, required this.count});

  /// Notifie quand le compteur change (ex. : le contrôleur du panier).
  final Listenable listenable;
  final int Function() count;
}

/// Ce que chaque module déclare dans son fichier `<folder>_routes.dart`.
///
/// - [screens] : les écrans déjà développés (identifiant → constructeur).
///   Tout écran prévu dans `modules_config.dart` mais absent de cette table
///   affiche automatiquement une page placeholder.
/// - [transitions] : transition d'un écran (sinon glissement, ou fondu en
///   plein écran).
/// - [extraRoutes] : routes supplémentaires (ex. `restaurant/:id`), créées
///   avec [ModuleRoutes.route].
/// - [badge] : compteur affiché sur l'onglet du module (optionnel).
class ModuleRoutes {
  const ModuleRoutes({
    required this.moduleNumber,
    this.screens = const {},
    this.transitions = const {},
    this.extraRoutes = const [],
    this.badge,
  });

  final int moduleNumber;
  final Map<String, ScreenBuilder> screens;
  final Map<String, PageTransitionType> transitions;
  final List<RouteBase> extraRoutes;
  final TabBadge? badge;

  /// `true` si l'écran est développé (sinon : placeholder).
  bool isReady(String screenId) => screens.containsKey(screenId);

  /// Route d'un module, placée sous sa route de base.
  /// [fullScreen] : ouverte sur le navigateur racine, sans la barre du bas.
  static GoRoute route(
    String path,
    ScreenBuilder builder, {
    bool fullScreen = false,
    PageTransitionType? transition,
  }) => GoRoute(
    path: path,
    parentNavigatorKey: fullScreen ? rootNavigatorKey : null,
    pageBuilder: (context, state) => buildTransitionPage(
      state: state,
      type:
          transition ??
          (fullScreen ? PageTransitionType.fade : PageTransitionType.slide),
      child: builder(context, state),
    ),
  );

  /// Écran principal du module, affiché à la racine de son onglet.
  Widget buildHome(
    BuildContext context,
    GoRouterState state,
    AppModule module,
  ) {
    final screen = module.screen(module.homeScreen)!;
    return screens[screen.id]?.call(context, state) ??
        PlaceholderPage(module: module, screen: screen);
  }

  /// Sous-routes du module : un écran prévu = une route (sauf l'écran
  /// principal, servi sur la route du module).
  List<RouteBase> routesFor(AppModule module) => [
    for (final screen in module.screens)
      if (screen.id != module.homeScreen)
        route(
          screen.id,
          screens[screen.id] ??
              (context, state) =>
                  PlaceholderPage(module: module, screen: screen),
          fullScreen: screen.fullScreen,
          transition: transitions[screen.id],
        ),
    ...extraRoutes,
  ];
}
