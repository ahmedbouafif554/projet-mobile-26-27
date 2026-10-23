import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/orders/presentation/controllers/orders_controller.dart';
import '../widgets/animated_bottom_nav.dart';

/// Squelette des 4 onglets principaux avec la barre de navigation animée.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final orders = OrdersController.instance;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ListenableBuilder(
        listenable: orders,
        builder: (context, _) => AnimatedBottomNav(
          currentIndex: navigationShell.currentIndex,
          // Un second appui sur l'onglet actif revient à sa racine.
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          items: [
            const BottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Accueil',
            ),
            const BottomNavItem(
              icon: Icons.search_rounded,
              activeIcon: Icons.manage_search_rounded,
              label: 'Recherche',
            ),
            BottomNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Commandes',
              showDot: orders.hasActiveOrder,
            ),
            const BottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
