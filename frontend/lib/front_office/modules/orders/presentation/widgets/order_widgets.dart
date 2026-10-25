import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../providers/cart_controller.dart';

/// Récapitulatif des montants (panier, paiement, fiche commande).
class TotalsCard extends StatelessWidget {
  const TotalsCard({super.key, required this.totals, this.promoCode});

  final CartTotals totals;
  final String? promoCode;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, double value, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: (bold ? context.text.titleMedium : context.text.bodyMedium)
                      ?.copyWith(color: color),
                ),
              ),
              Text(
                Formatters.price(value),
                style: (bold ? context.text.titleMedium : context.text.bodyMedium)
                    ?.copyWith(color: color),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        children: [
          line('Sous-total', totals.subtotal),
          line('Livraison', totals.deliveryFee),
          line('Frais de service', totals.serviceFee),
          if (totals.discount > 0)
            line(
              promoCode == null ? 'Réduction' : 'Code $promoCode',
              -totals.discount,
              color: AppColors.success,
            ),
          const Divider(height: 20),
          line('Total', totals.total, bold: true),
        ],
      ),
    );
  }
}

/// Bloc avec titre (paiement, adresse…).
class TitledBlock extends StatelessWidget {
  const TitledBlock({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: context.text.titleMedium)),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        child,
      ],
    );
  }
}

/// Carte blanche arrondie.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: context.palette.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
