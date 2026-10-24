import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/page_transitions.dart';

/// Page de la coque du back office : fondu court entre deux écrans du menu.
GoRoute boRoute(
  String path,
  Widget Function(BuildContext context, GoRouterState state) builder, {
  List<RouteBase> routes = const [],
}) => transitionRoute(
  path,
  builder,
  type: PageTransitionType.fade,
  routes: routes,
);
