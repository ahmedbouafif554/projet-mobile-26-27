import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_sizes.dart';
import '../../core/widgets/page_header.dart';
import '../router/back_routes.dart';
import 'back_nav.dart';

/// Squelette d'une page du back office : marges, largeur maximale, en-tête
/// (fil d'Ariane « Tableau de bord › module › page », titre, actions) et
/// contenu défilant.
///
/// [scrollable] à false donne au contenu toute la hauteur restante (Kanban,
/// conversation, carte).
class BoPage extends StatelessWidget {
  const BoPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.onAdd,
    this.addLabel = 'Ajouter',
    this.addIcon = Icons.add_rounded,
    this.parent,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onAdd;
  final String addLabel;
  final IconData addIcon;

  /// Page parente cliquable (pages de détail : « Utilisateurs »).
  final BreadcrumbItem? parent;
  final List<Widget> children;
  final bool scrollable;

  List<BreadcrumbItem> _breadcrumbs(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path == BackRoutes.dashboard) return const [];
    final group = navGroupTitleFor(path);
    return [
      BreadcrumbItem(
        'Tableau de bord',
        onTap: () => context.go(BackRoutes.dashboard),
      ),
      if (group != null && group != title && group != parent?.label)
        BreadcrumbItem(group),
      ?parent,
      BreadcrumbItem(title),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width < Breakpoints.compact
        ? AppSizes.md
        : AppSizes.lg;
    final header = PageHeader(
      title: title,
      subtitle: subtitle,
      breadcrumbs: _breadcrumbs(context),
      actions: actions,
      onAdd: onAdd,
      addLabel: addLabel,
      addIcon: addIcon,
    );

    Widget frame(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
        child: child,
      ),
    );

    if (!scrollable) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: frame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: AppSizes.lg),
            ...children,
            const SizedBox(height: AppSizes.xl),
          ],
        ),
      ),
    );
  }
}

/// Espace vertical standard entre deux blocs d'une page.
const boGap = SizedBox(height: AppSizes.md);
