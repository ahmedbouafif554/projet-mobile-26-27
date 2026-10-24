import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';

/// Conteneur des onglets (branches go_router) avec un fondu enchaîné
/// lors du changement d'onglet. Chaque onglet garde son état.
///
/// Les onglets inactifs sont désactivés (tickers, clics, Hero) pour éviter
/// les conflits de tags Hero entre onglets.
class AnimatedBranchContainer extends StatelessWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          AnimatedOpacity(
            opacity: i == currentIndex ? 1 : 0,
            duration: AppDurations.medium,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: i != currentIndex,
              child: TickerMode(
                enabled: i == currentIndex,
                child: HeroMode(
                  enabled: i == currentIndex,
                  child: ExcludeFocus(
                    excluding: i != currentIndex,
                    child: children[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
