import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/quantity_selector.dart';
import '../../models/cart_item.dart';

/// Ligne du panier : photo, options, prix et sélecteur de quantité.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNetworkImage(
            item.product.imageUrl,
            width: 76,
            height: 76,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            fallbackIcon: Icons.fastfood_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.optionsLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.optionsLabel,
                    style: context.text.bodySmall,
                    maxLines: 2,
                  ),
                ],
                if (item.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '« ${item.note} »',
                    style: context.text.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedPrice(
                        item.totalPrice,
                        style: context.text.titleSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    QuantitySelector(
                      value: item.quantity,
                      onChanged: onQuantityChanged,
                      onRemove: onRemove,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
