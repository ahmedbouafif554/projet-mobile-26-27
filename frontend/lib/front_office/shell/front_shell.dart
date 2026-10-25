import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import 'front_tabs.dart';

/// Coque du front office : onglets + barre de navigation Material 3 animée.
class FrontShell extends StatelessWidget {
  const FrontShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
  });

  final StatefulNavigationShell navigationShell;
  final List<FrontTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AnimatedNavBar(
        tabs: tabs,
        currentIndex: navigationShell.currentIndex,
        // Un second appui sur l'onglet actif revient à son écran principal.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// NavigationBar Material 3 : l'icône change et rebondit, un trait glisse
/// au-dessus de l'onglet actif et les compteurs apparaissent en rebond.
class AnimatedNavBar extends ConsumerWidget {
  const AnimatedNavBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<FrontTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static int _count(WidgetRef ref, FrontTab tab) =>
      tab.badge == null ? 0 : ref.watch(tab.badge!).value ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = tabs.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelected,
            animationDuration: const Duration(milliseconds: 450),
            destinations: [
              for (final (i, tab) in tabs.indexed)
                NavigationDestination(
                  label: tab.label,
                  tooltip: tab.label,
                  icon: _TabIcon(icon: tab.icon, count: _count(ref, tab)),
                  selectedIcon: _TabIcon(
                    icon: tab.selectedIcon,
                    count: _count(ref, tab),
                    bounce: i == currentIndex,
                  ),
                ),
            ],
          ),
          // Trait orange qui glisse au-dessus de l'onglet actif.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              alignment: Alignment(
                count == 1 ? 0 : -1 + 2 * currentIndex / (count - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.count,
    this.bounce = false,
  });

  final IconData icon;
  final int count;

  /// Rebond à la sélection (l'icône sélectionnée est recréée à chaque fois).
  final bool bounce;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon);
    if (bounce) {
      iconWidget = iconWidget
          .animate()
          .scaleXY(
            begin: 0.6,
            end: 1,
            duration: 550.ms,
            curve: Curves.elasticOut,
          )
          .rotate(begin: -0.06, end: 0, duration: 300.ms);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        if (count > 0)
          Positioned(
            top: -6,
            right: -12,
            child:
                Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.badge,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: context.colors.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    )
                    // La clé change avec la valeur : le rebond est rejoué.
                    .animate(key: ValueKey(count))
                    .scaleXY(
                      begin: 0.3,
                      end: 1,
                      duration: AppDurations.slow,
                      curve: Curves.elasticOut,
                    ),
          ),
      ],
    );
  }
}
