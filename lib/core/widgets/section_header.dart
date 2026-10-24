import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// En-tête de section : titre + lien « Voir tout » optionnel.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel = 'Voir tout',
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (onAction != null)
            Pressable(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: context.text.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
