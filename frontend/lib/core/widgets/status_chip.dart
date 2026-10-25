import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';

/// Tonalités standard des statuts (commande livrée = succès…).
enum StatusTone { success, warning, danger, info, primary, neutral }

/// Pastille de statut : point ou icône + libellé, sur fond teinté.
/// La couleur change en douceur quand le statut change.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;

  /// Couleur libre (remplace [tone]).
  final Color? color;
  final IconData? icon;
  final bool dense;

  static Color toneColor(BuildContext context, StatusTone tone) =>
      switch (tone) {
        StatusTone.success => context.palette.success,
        StatusTone.warning => context.palette.warning,
        StatusTone.danger => context.colors.error,
        StatusTone.info => context.palette.info,
        StatusTone.primary => AppColors.primary,
        StatusTone.neutral => context.palette.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final c = color ?? toneColor(context, tone);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: dense ? 12 : 14, color: c)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          SizedBox(width: dense ? 4 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (dense ? context.text.labelSmall : context.text.labelMedium)
                      ?.copyWith(color: c, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
