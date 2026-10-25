import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import '../utils/formatters.dart';
import 'animated_counter.dart';
import 'app_card.dart';

/// Carte de statistique : icône, libellé, compteur animé et tendance.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.format = Formatters.count,
    this.color = AppColors.primary,
    this.trend,
    this.caption,
    this.onTap,
  });

  final String label;
  final num value;
  final IconData icon;

  /// Affichage de la valeur (ex. `Formatters.priceShort`).
  final String Function(num value) format;
  final Color color;

  /// Évolution en % par rapport à la période précédente.
  final double? trend;

  /// Texte sous la valeur (« vs hier »).
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSizes.sm),
              // La tendance se réduit si la carte est étroite.
              if (trend != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _TrendChip(trend: trend!),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: value,
              format: format,
              style: context.text.headlineMedium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    final color = up ? context.palette.success : context.colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            Formatters.trend(trend),
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
