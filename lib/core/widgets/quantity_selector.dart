import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Sélecteur de quantité « −  2  + » avec chiffre animé.
/// Si [onRemove] est fourni, le bouton « − » devient une corbeille
/// lorsque la quantité est au minimum.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.onRemove,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final VoidCallback? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    final atMin = value <= min;
    final showRemove = atMin && onRemove != null;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            size: size,
            icon: showRemove
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            color: showRemove ? AppColors.error : null,
            onTap: showRemove
                ? onRemove
                : atMin
                ? null
                : () => onChanged(value - 1),
          ),
          SizedBox(
            width: compact ? 28 : 40,
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: compact
                    ? context.text.titleSmall
                    : context.text.titleMedium,
              ),
            ),
          ),
          _StepButton(
            size: size,
            icon: Icons.add_rounded,
            filled: true,
            onTap: value >= max ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.size,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.color,
  });

  final double size;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? AppColors.primary : context.palette.border)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.fast,
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: size * 0.55,
            color: filled
                ? Colors.white
                : (color ??
                      (enabled
                          ? context.colors.onSurface
                          : context.palette.textSecondary)),
          ),
        ),
      ),
    );
  }
}
