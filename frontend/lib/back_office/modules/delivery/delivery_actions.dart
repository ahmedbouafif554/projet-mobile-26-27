import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../shared/models/models.dart';
import 'delivery_controllers.dart';

// =============================================================================
// Actions sur les livreurs et les livraisons (tableaux, fiches, carte).
// =============================================================================

/// Valide ou refuse les justificatifs d'un livreur.
Future<void> reviewCourierDocuments(
  BuildContext context,
  WidgetRef ref,
  Courier courier,
  DocumentStatus status,
) async {
  if (status == DocumentStatus.rejected) {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Refuser les justificatifs ?',
      message:
          '${courier.fullName} devra envoyer de nouveaux documents avant de '
          'pouvoir livrer.',
      confirmLabel: 'Refuser',
      icon: Icons.gpp_bad_outlined,
    );
    if (!confirmed) return;
  }
  try {
    await ref
        .read(couriersControllerProvider.notifier)
        .reviewDocuments(courier, status);
    if (context.mounted) {
      AppSnackbar.success(
        context,
        status == DocumentStatus.approved
            ? 'Justificatifs de ${courier.firstName} validés'
            : 'Justificatifs de ${courier.firstName} refusés',
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Change le statut en ligne d'un livreur.
Future<void> setCourierStatus(
  BuildContext context,
  WidgetRef ref,
  Courier courier,
  CourierStatus status,
) async {
  try {
    await ref.read(couriersControllerProvider.notifier).setStatus(courier, status);
    if (context.mounted) {
      AppSnackbar.success(context, '${courier.fullName} : ${status.label}');
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Étape suivante d'une course.
DeliveryStatus? nextDeliveryStatus(DeliveryStatus status) => switch (status) {
  DeliveryStatus.assigned => DeliveryStatus.pickedUp,
  DeliveryStatus.pickedUp => DeliveryStatus.inTransit,
  DeliveryStatus.inTransit => DeliveryStatus.delivered,
  _ => null,
};

String deliveryStepAction(DeliveryStatus next) => switch (next) {
  DeliveryStatus.pickedUp => 'Marquer récupérée',
  DeliveryStatus.inTransit => 'Marquer en route',
  DeliveryStatus.delivered => 'Marquer livrée',
  _ => next.label,
};

Future<void> updateDeliveryStatus(
  BuildContext context,
  WidgetRef ref,
  Delivery delivery,
  DeliveryStatus status,
) async {
  if (status == DeliveryStatus.cancelled) {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Annuler la course #${delivery.orderReference} ?',
      message: 'Le livreur assigné sera libéré.',
      confirmLabel: 'Annuler la course',
      icon: Icons.cancel_outlined,
    );
    if (!confirmed) return;
  }
  try {
    await ref
        .read(deliveriesControllerProvider.notifier)
        .updateStatus(delivery, status);
    if (context.mounted) {
      AppSnackbar.success(
        context,
        'Course #${delivery.orderReference} : ${status.label}',
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Choisit un livreur disponible (justificatifs validés) et l'assigne.
Future<void> assignCourier(
  BuildContext context,
  WidgetRef ref,
  Delivery delivery,
) async {
  final couriers = await ref.read(couriersControllerProvider.future);
  if (!context.mounted) return;
  final candidates =
      couriers
          .where(
            (c) =>
                c.status == CourierStatus.available &&
                c.documentStatus == DocumentStatus.approved,
          )
          .toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
  final courier = await showDialog<Courier>(
    context: context,
    builder: (_) => _AssignDialog(delivery: delivery, couriers: candidates),
  );
  if (courier == null || !context.mounted) return;
  try {
    await ref.read(deliveriesControllerProvider.notifier).assign(delivery, courier);
    if (context.mounted) {
      AppSnackbar.success(
        context,
        '${courier.fullName} livre la commande #${delivery.orderReference}',
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.delivery, required this.couriers});

  final Delivery delivery;
  final List<Courier> couriers;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late Courier? _selected = widget.couriers.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    return AlertDialog(
      title: Text('Assigner #${d.orderReference}'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${d.pickupName} → ${d.dropoffAddress}\n'
                '${Formatters.distance(d.distanceKm)} • ~${d.estimatedMinutes} min • '
                '${Formatters.price(d.earnings)} pour le livreur',
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            if (widget.couriers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 40,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aucun livreur disponible pour le moment.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final c in widget.couriers)
                        RadioListTile<Courier>(
                          value: c,
                          groupValue: _selected,
                          onChanged: (v) => setState(() => _selected = v),
                          secondary: Avatar(
                            name: c.fullName,
                            imageUrl: c.avatarUrl,
                            size: 40,
                          ),
                          title: Text(c.fullName),
                          subtitle: Text(
                            '${c.vehicle.label} • ${c.zone} • ★ ${Formatters.rating(c.rating)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Assigner'),
        ),
      ],
    );
  }
}

/// Icône du véhicule.
IconData vehicleIcon(VehicleType vehicle) => switch (vehicle) {
  VehicleType.bike => Icons.pedal_bike_rounded,
  VehicleType.scooter => Icons.two_wheeler_rounded,
  VehicleType.car => Icons.directions_car_rounded,
};

/// Couleur d'un livreur sur la carte et dans les listes.
Color courierColor(CourierStatus status) => switch (status) {
  CourierStatus.available => AppColors.success,
  CourierStatus.busy => AppColors.primary,
  CourierStatus.offline => AppColors.textSecondary,
};
