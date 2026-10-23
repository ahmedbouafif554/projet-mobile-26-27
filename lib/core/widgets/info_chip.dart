import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Petite information « icône + texte » (note, durée, distance, frais...).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? context.palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: textColor ?? context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Pastille de note « ★ 4,8 ».
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 15, color: context.palette.warning),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1).replaceAll('.', ','),
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
