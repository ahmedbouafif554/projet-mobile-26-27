import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../config/modules_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../routes/module_routes.dart';
import '../theme/theme_extensions.dart';
import 'app_snackbar.dart';

/// Coque de l'application : barre de navigation du bas, avec un onglet
/// par module (chaque onglet garde son historique).
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
    this.badges = const {},
  });

  final StatefulNavigationShell navigationShell;

  /// Compteurs des onglets, indexés par numéro de module.
  final Map<int, TabBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Messager propre aux onglets : les snackbars des pages s'affichent
      // dans la page (au-dessus de sa barre du bas), pas sur la navigation.
      body: ScaffoldMessenger(
        key: AppSnackbar.shellMessengerKey,
        child: navigationShell,
      ),
      bottomNavigationBar: ModuleNavigationBar(
        currentIndex: navigationShell.currentIndex,
        badges: badges,
        // Un second appui sur l'onglet actif revient à son écran principal.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// NavigationBar Material 3 générée depuis la configuration des modules :
/// icône qui change et rebondit, indicateur coloré qui glisse, badges animés.
class ModuleNavigationBar extends StatelessWidget {
  const ModuleNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.badges = const {},
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Map<int, TabBadge> badges;

  @override
  Widget build(BuildContext context) {
    final modules = ModulesConfig.modules;
    final accent = modules[currentIndex].accent;
    final count = modules.length;

    return ListenableBuilder(
      listenable: Listenable.merge([
        for (final badge in badges.values) badge.listenable,
      ]),
      builder: (context, _) => DecoratedBox(
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
              indicatorColor: accent.withValues(alpha: 0.16),
              animationDuration: const Duration(milliseconds: 450),
              destinations: [
                for (final (i, module) in modules.indexed)
                  NavigationDestination(
                    tooltip: module.name,
                    label: module.label,
                    icon: _TabIcon(
                      icon: module.icon,
                      count: badges[module.number]?.count() ?? 0,
                    ),
                    selectedIcon: _TabIcon(
                      icon: module.selectedIcon,
                      color: module.accent,
                      count: badges[module.number]?.count() ?? 0,
                      bounce: i == currentIndex,
                    ),
                  ),
              ],
            ),
            // Trait coloré qui glisse sous l'onglet actif.
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
                    child: AnimatedContainer(
                      duration: AppDurations.medium,
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.vertical(
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
      ),
    );
  }
}

/// Icône d'onglet avec badge optionnel.
class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.count,
    this.color,
    this.bounce = false,
  });

  final IconData icon;
  final int count;
  final Color? color;

  /// Rebond à la sélection (l'icône sélectionnée est recréée à chaque fois).
  final bool bounce;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: color);
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
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
          ),
      ],
    );
  }
}
