import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../providers/courier_providers.dart';

/// Libellé du bouton de l'étape suivante d'une course.
String? nextStepLabel(DeliveryStatus status) => switch (status) {
  DeliveryStatus.assigned => 'J’ai récupéré la commande',
  DeliveryStatus.pickedUp => 'Je pars livrer',
  DeliveryStatus.inTransit => 'Commande livrée',
  _ => null,
};

/// Fait avancer une course (avec message de confirmation).
Future<void> advanceDelivery(
  BuildContext context,
  WidgetRef ref,
  Delivery delivery,
) async {
  try {
    await ref.read(myDeliveriesProvider.notifier).advance(delivery);
    if (!context.mounted) return;
    AppSnackbar.success(
      context,
      delivery.status == DeliveryStatus.inTransit
          ? 'Livraison terminée : +${Formatters.price(delivery.earnings)} 🎉'
          : 'Course mise à jour',
    );
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Trajet retrait → livraison.
class RouteSummary extends StatelessWidget {
  const RouteSummary({super.key, required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    Widget stop(IconData icon, Color color, String title, String subtitle) =>
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    return Column(
      children: [
        stop(
          Icons.storefront_rounded,
          AppColors.primary,
          delivery.pickupName,
          delivery.pickupAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 18,
              color: context.palette.border,
            ),
          ),
        ),
        stop(
          Icons.location_on_rounded,
          AppColors.success,
          delivery.customerName,
          delivery.dropoffAddress,
        ),
      ],
    );
  }
}

/// Carte d'une course (proposée, en cours ou terminée).
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.delivery,
    this.onTap,
    this.actions,
  });

  final Delivery delivery;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: context.palette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '#${d.orderReference}',
                          style: context.text.titleMedium,
                        ),
                        deliveryStatusChip(d.status),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.price(d.earnings),
                        style: context.text.titleMedium?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      if (d.tip > 0)
                        Text(
                          'dont ${Formatters.price(d.tip)} de pourboire',
                          style: context.text.labelSmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RouteSummary(delivery: d),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Pill(
                    icon: Icons.route_rounded,
                    label: Formatters.distance(d.distanceKm),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.schedule_rounded,
                    label: '~${d.estimatedMinutes} min',
                  ),
                  const Spacer(),
                  Text(
                    Formatters.relative(d.deliveredAt ?? d.createdAt),
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.palette.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: context.text.labelMedium),
        ],
      ),
    );
  }
}
