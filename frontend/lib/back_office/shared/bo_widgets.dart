import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/avatar.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/status_chips.dart';
import '../router/back_routes.dart';

// =============================================================================
// Petits blocs de mise en page partagés par les pages du back office.
// =============================================================================

/// Grille de cartes qui passe de 4 à 2 puis 1 colonne selon la largeur,
/// avec une apparition en cascade.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 230,
    this.maxColumns = 4,
    this.spacing = AppSizes.md,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minItemWidth).floor().clamp(1, maxColumns);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (i, child) in children.indexed)
              SizedBox(width: itemWidth, child: child)
                  .animate(delay: (70 * i).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, end: 0),
          ],
        );
      },
    );
  }
}

/// Deux blocs côte à côte sur grand écran, l'un sous l'autre sinon.
class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 3,
    this.rightFlex = 2,
    this.breakpoint = 900,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: AppSizes.md), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: AppSizes.md),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

/// Carte avec un titre (et une action à droite).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSizes.md + 4),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSizes.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

/// Ligne « icône • libellé • valeur » des fiches de détail.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: context.palette.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                DefaultTextStyle.merge(
                  style: context.text.titleSmall,
                  child: value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourci : [InfoRow] avec un texte.
InfoRow infoText(IconData icon, String label, String value) =>
    InfoRow(icon: icon, label: label, value: Text(value));

/// Ligne d'une commande (dernières commandes, fiche client…).
class OrderListTile extends StatelessWidget {
  const OrderListTile({
    super.key,
    required this.order,
    this.showRestaurant = true,
  });

  final Order order;
  final bool showRestaurant;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    return InkWell(
      onTap: () => context.go(BackRoutes.order(order.id)),
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Avatar(name: order.customerName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.reference} • ${order.customerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    [
                      if (showRestaurant) order.restaurantName,
                      '${order.itemCount} article${order.itemCount > 1 ? 's' : ''}',
                      Formatters.relative(order.createdAt),
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.price(order.total),
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 4),
                orderStatusChip(order.status, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste séparée par des traits fins.
class DividedColumn extends StatelessWidget {
  const DividedColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) Divider(height: 1, color: context.palette.border),
          child,
        ],
      ],
    );
  }
}

/// Petit compteur de synthèse en tête de tableau (« 12 clients »).
class SummaryPill extends StatelessWidget {
  const SummaryPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : context.colors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: selected ? color : context.palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                '$value',
                style: context.text.titleMedium?.copyWith(color: color),
              ),
              const SizedBox(width: 6),
              Text(label, style: context.text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
