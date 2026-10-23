import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/animated_price.dart';

/// Détail du total : sous-total, frais, réduction et total.
/// Chaque montant s'anime lorsqu'il change.
class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          _PriceRow(label: 'Sous-total', value: subtotal),
          _PriceRow(
            label: 'Frais de livraison',
            value: deliveryFee,
            freeLabel: 'Offerts',
          ),
          _PriceRow(label: 'Frais de service', value: serviceFee),
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            child: discount > 0
                ? _PriceRow(
                    label: 'Réduction',
                    value: discount,
                    prefix: '- ',
                    color: AppColors.success,
                  )
                : const SizedBox(width: double.infinity),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            children: [
              Text('Total', style: context.text.titleMedium),
              const Spacer(),
              AnimatedPrice(
                total,
                style: context.text.titleLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.freeLabel,
    this.prefix = '',
    this.color,
  });

  final String label;
  final double value;

  /// Texte affiché à la place de « 0,00 € » (ex. : « Offerts »).
  final String? freeLabel;
  final String prefix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: color ?? context.palette.textSecondary,
            ),
          ),
          const Spacer(),
          if (freeLabel != null && value == 0)
            Text(
              freeLabel!,
              style: context.text.labelLarge?.copyWith(
                color: AppColors.success,
              ),
            )
          else
            AnimatedPrice(value, prefix: prefix, style: style),
        ],
      ),
    );
  }
}
