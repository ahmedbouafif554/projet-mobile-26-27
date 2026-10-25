import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';

/// Élément du fil d'Ariane (cliquable s'il a un [onTap]).
class BreadcrumbItem {
  const BreadcrumbItem(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;
}

/// Fil d'Ariane : « Tableau de bord › Catalogue › Produits ».
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.items});

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: context.palette.textSecondary,
              ),
            ),
          if (item.onTap != null && i < items.length - 1)
            InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(item.label, style: muted),
              ),
            )
          else
            Text(
              item.label,
              style: i == items.length - 1
                  ? context.text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                  : muted,
            ),
        ],
      ],
    );
  }
}

/// En-tête de page : fil d'Ariane, titre, sous-titre, actions et bouton
/// « Ajouter ». Passe sur deux lignes sur les écrans étroits.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumbs = const [],
    this.actions = const [],
    this.onAdd,
    this.addLabel = 'Ajouter',
    this.addIcon = Icons.add_rounded,
  });

  final String title;
  final String? subtitle;
  final List<BreadcrumbItem> breadcrumbs;
  final List<Widget> actions;

  /// Affiche le bouton principal « Ajouter » s'il est fourni.
  final VoidCallback? onAdd;
  final String addLabel;
  final IconData addIcon;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ],
    );

    final buttons = [
      ...actions,
      if (onAdd != null)
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: Icon(addIcon),
          label: Text(addLabel),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (breadcrumbs.isNotEmpty) ...[
              Breadcrumbs(items: breadcrumbs),
              const SizedBox(height: AppSizes.sm),
            ],
            if (narrow) ...[
              titleBlock,
              if (buttons.isNotEmpty) ...[
                const SizedBox(height: AppSizes.md),
                Wrap(spacing: 8, runSpacing: 8, children: buttons),
              ],
            ] else
              Row(
                children: [
                  Expanded(child: titleBlock),
                  for (final b in buttons) ...[
                    const SizedBox(width: AppSizes.sm),
                    b,
                  ],
                ],
              ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
      },
    );
  }
}
