import 'package:flutter/widgets.dart';

import '../theme/app_sizes.dart';

/// Taille d'écran courante (voir [Breakpoints]).
enum ScreenType { compact, medium, expanded }

extension ResponsiveContextX on BuildContext {
  ScreenType get screenType {
    final width = MediaQuery.sizeOf(this).width;
    if (width < Breakpoints.compact) return ScreenType.compact;
    if (width < Breakpoints.expanded) return ScreenType.medium;
    return ScreenType.expanded;
  }

  /// Téléphone : une colonne, menu en Drawer.
  bool get isCompact => screenType == ScreenType.compact;

  /// Grand écran : sidebar dépliée, tableaux complets.
  bool get isExpanded => screenType == ScreenType.expanded;
}

/// Choisit un widget selon la largeur disponible (et non celle de l'écran),
/// pour s'adapter aussi à l'intérieur d'une carte ou d'un panneau.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width >= Breakpoints.expanded && expanded != null) {
        return expanded!(context);
      }
      if (width >= Breakpoints.compact) {
        return (medium ?? expanded ?? compact)(context);
      }
      return compact(context);
    },
  );
}
