import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/models/user.dart';
import '../router/back_routes.dart';
import 'back_nav.dart';
import 'back_topbar.dart';

/// Largeur d'un téléphone : l'Espace Pro reste une application mobile,
/// même lorsqu'il est ouvert dans une fenêtre de navigateur large.
const double _phoneWidth = 430;

/// Coque mobile du back office : cadre téléphone, barre du haut et
/// navigation en bas. Les autres modules sont dans l'onglet Plus.
class BackShell extends ConsumerWidget {
  const BackShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).user;
    final width = MediaQuery.sizeOf(context).width;
    final phone = width > _phoneWidth ? _phoneWidth : width;

    return ColoredBox(
      color: context.palette.border.withValues(alpha: 0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: phone),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: Size(phone, MediaQuery.sizeOf(context).height)),
            child: Scaffold(
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    BackTopbar(
                      location: location,
                      compact: true,
                      showMenu: false,
                      onMenu: () {},
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
              bottomNavigationBar: user == null
                  ? null
                  : _AdminNav(location: location, role: user.role),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNav extends ConsumerWidget {
  const _AdminNav({required this.location, required this.role});

  final String location;
  final UserRole role;

  static const _primary = [
    BackRoutes.dashboard,
    BackRoutes.orders,
    BackRoutes.deliveries,
    BackRoutes.restaurants,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [for (final group in navFor(role)) ...group.items];
    final primary = [
      for (final path in _primary)
        if (items.any((item) => item.path == path))
          items.firstWhere((item) => item.path == path),
    ];
    if (primary.isEmpty && items.isNotEmpty) primary.add(items.first);
    final more = [
      for (final item in items)
        if (!primary.contains(item)) item,
    ];
    final onMore = more.any(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );
    final selected = onMore
        ? primary.length
        : primary.indexWhere(
            (item) =>
                location == item.path || location.startsWith('${item.path}/'),
          );

    return NavigationBar(
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) {
        if (index == primary.length) {
          _openMore(context, more);
          return;
        }
        context.go(primary[index].path);
      },
      destinations: [
        for (final item in primary)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.labelFor(role),
          ),
        if (more.isNotEmpty)
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Plus',
          ),
      ],
    );
  }

  void _openMore(BuildContext context, List<BackNavItem> more) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in more)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.labelFor(role)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(item.path);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Mon compte'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(BackRoutes.account);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
