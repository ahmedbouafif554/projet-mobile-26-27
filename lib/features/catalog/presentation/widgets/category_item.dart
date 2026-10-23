import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/food_category.dart';

/// Pastille de catégorie : emoji sur fond coloré + libellé.
class CategoryItem extends StatelessWidget {
  const CategoryItem({super.key, required this.category, required this.onTap});

  final FoodCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: true,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // En mode sombre, on atténue les pastels.
                color: context.isDark
                    ? category.color.withValues(alpha: 0.14)
                    : category.color,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: context.text.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
