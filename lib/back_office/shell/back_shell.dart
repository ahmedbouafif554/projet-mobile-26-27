import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_sizes.dart';
import 'back_sidebar.dart';
import 'back_topbar.dart';
import 'sidebar_state.dart';

/// Coque du back office : sidebar + topbar autour de la page courante.
///
/// - grand écran (≥ 1024 px) : sidebar dépliée ;
/// - tablette (600–1024 px) : sidebar repliée (icônes) ;
/// - téléphone (< 600 px) : menu dans un Drawer.
///
/// Le bouton « Replier » mémorise le choix de l'utilisateur.
class BackShell extends ConsumerStatefulWidget {
  const BackShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<BackShell> createState() => _BackShellState();
}

class _BackShellState extends ConsumerState<BackShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Breakpoints.compact;
    final collapsed =
        ref.watch(sidebarCollapsedProvider) ?? width < Breakpoints.expanded;

    final topbar = BackTopbar(
      location: widget.location,
      compact: compact,
      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
    );

    if (compact) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: SidebarWidth.expanded,
          child: SafeArea(
            child: BackSidebar(
              location: widget.location,
              collapsed: false,
              onNavigate: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              topbar,
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          BackSidebar(
            location: widget.location,
            collapsed: collapsed,
            onToggle: () => ref
                .read(sidebarCollapsedProvider.notifier)
                .toggle(currentlyCollapsed: collapsed),
          ),
          Expanded(
            child: Column(
              children: [
                topbar,
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
