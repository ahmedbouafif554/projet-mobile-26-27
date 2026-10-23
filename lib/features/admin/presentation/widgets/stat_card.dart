import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../models/admin_stat.dart';

/// Carte d'indicateur clé (KPI) avec tendance.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    final up = stat.trend >= 0;
    final trendColor = up ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(stat.icon, color: stat.color, size: 20),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(stat.value, style: context.text.headlineSmall),
          ),
          Text(
            stat.label,
            style: context.text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: trendColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${up ? '+' : ''}${stat.trend.toStringAsFixed(1).replaceAll('.', ',')} %',
                style: context.text.labelMedium?.copyWith(color: trendColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
