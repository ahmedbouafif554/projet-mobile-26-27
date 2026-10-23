import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Sélecteur segmenté Clair / Sombre / Auto : la pastille glisse
/// sous l'option choisie et le thème change instantanément.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  static const _modes = [
    (ThemeMode.light, Icons.light_mode_rounded, 'Clair'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Sombre'),
    (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final index = _modes.indexWhere((m) => m.$1 == controller.mode);

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Stack(
            children: [
              // Pastille animée
              AnimatedAlign(
                duration: AppDurations.medium,
                curve: Curves.easeOutBack,
                alignment: Alignment(-1 + index * 1.0, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / _modes.length,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      boxShadow: context.palette.softShadow,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, mode) in _modes.indexed)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.setMode(mode.$1);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode.$2,
                              size: 18,
                              color: i == index
                                  ? AppColors.primary
                                  : context.palette.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            AnimatedDefaultTextStyle(
                              duration: AppDurations.fast,
                              style: context.text.labelLarge!.copyWith(
                                color: i == index
                                    ? context.colors.onSurface
                                    : context.palette.textSecondary,
                              ),
                              child: Text(mode.$3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
