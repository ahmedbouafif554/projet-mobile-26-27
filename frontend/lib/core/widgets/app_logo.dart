import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_extensions.dart';

/// Logo SuperFaster : éclair blanc dans un carré arrondi orange,
/// avec le nom de l'application en option.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.showName = false});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * 0.62),
    );

    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.25),
        Text.rich(
          TextSpan(
            text: 'Super',
            style: context.text.titleLarge,
            children: const [
              TextSpan(
                text: 'Faster',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
