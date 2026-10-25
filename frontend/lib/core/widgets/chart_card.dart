import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'app_card.dart';

/// Carte contenant un graphique : titre, sous-titre, action (sélecteur de
/// période…) et zone de hauteur fixe.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height = 260,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// Hauteur de la zone du graphique.
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
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
          const SizedBox(height: AppSizes.md + 4),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
