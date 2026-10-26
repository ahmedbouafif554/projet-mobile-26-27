import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'courier_form.dart';
import 'delivery_actions.dart';
import 'delivery_controllers.dart';

/// Fiche d'un livreur : activité, justificatifs et courses.
class CourierDetailPage extends ConsumerWidget {
  const CourierDetailPage({super.key, required this.courierId});

  final String courierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couriers = ref.watch(couriersControllerProvider);
    final parent = BreadcrumbItem(
      'Livreurs',
      onTap: () => context.go(BackRoutes.couriers),
    );
    final courier = couriers.value?.where((c) => c.id == courierId).firstOrNull;
    if (courier == null) {
      return BoPage(
        title: couriers.isLoading ? 'Chargement…' : 'Livreur introuvable',
        parent: parent,
        children: [
          if (couriers.isLoading)
            const ShimmerScope(
              child: SkeletonBox(height: 220, radius: AppSizes.radiusLg),
            )
          else
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.delivery_dining_rounded,
                title: 'Livreur introuvable',
                message: 'Ce livreur a peut-être été supprimé.',
                actionLabel: 'Retour à la liste',
                onAction: () => context.go(BackRoutes.couriers),
              ),
            ),
        ],
      );
    }

    final c = courier;
    final deliveries = (ref.watch(deliveriesControllerProvider).value ?? [])
        .where((d) => d.courierId == c.id)
        .toList();
    final current = deliveries.where((d) => d.status.isActive).firstOrNull;

    return BoPage(
      title: c.fullName,
      parent: parent,
      actions: [
        OutlinedButton.icon(
          onPressed: () => openCourierForm(context, courier: c),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Modifier'),
        ),
        if (c.status != CourierStatus.busy)
          FilledButton.tonalIcon(
            onPressed: () => setCourierStatus(
              context,
              ref,
              c,
              c.status == CourierStatus.offline
                  ? CourierStatus.available
                  : CourierStatus.offline,
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.power_settings_new_rounded),
            label: Text(
              c.status == CourierStatus.offline
                  ? 'Mettre en ligne'
                  : 'Mettre hors ligne',
            ),
          ),
      ],
      children: [
        _Header(courier: c),
        boGap,
        ResponsiveGrid(
          children: [
            StatCard(
              label: 'Livraisons',
              value: c.completedDeliveries,
              icon: Icons.inventory_2_rounded,
              caption: 'Depuis l’inscription',
            ),
            StatCard(
              label: 'Gains totaux',
              value: c.totalEarnings,
              format: Formatters.priceShort,
              icon: Icons.euro_rounded,
              color: AppColors.success,
              caption: 'Pourboires inclus',
            ),
            StatCard(
              label: 'Note',
              value: c.rating,
              format: Formatters.rating,
              icon: Icons.star_rounded,
              color: AppColors.warning,
              caption: 'Moyenne des clients',
            ),
            StatCard(
              label: 'Courses en cours',
              value: deliveries.where((d) => d.status.isActive).length,
              icon: Icons.route_rounded,
              color: AppColors.info,
              caption: '${deliveries.length} sur la période',
            ),
          ],
        ),
        boGap,
        SplitRow(
          leftFlex: 2,
          rightFlex: 3,
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DocumentsCard(courier: c),
              boGap,
              SectionCard(
                title: 'Informations',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    infoText(Icons.phone_outlined, 'Téléphone', c.phone),
                    infoText(
                      vehicleIcon(c.vehicle),
                      'Véhicule',
                      c.plateNumber == null
                          ? c.vehicle.label
                          : '${c.vehicle.label} • ${c.plateNumber}',
                    ),
                    infoText(Icons.map_outlined, 'Zone', c.zone),
                    infoText(
                      Icons.event_rounded,
                      'Partenaire depuis',
                      Formatters.date(c.joinedAt),
                    ),
                  ],
                ),
              ),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (current != null) ...[
                _CurrentDelivery(delivery: current),
                boGap,
              ],
              SectionCard(
                title: 'Historique des courses',
                icon: Icons.history_rounded,
                subtitle: '${deliveries.length} course(s) sur la période',
                child: deliveries.isEmpty
                    ? const EmptyState(
                        compact: true,
                        icon: Icons.route_rounded,
                        title: 'Aucune course',
                        message: 'Les courses de ce livreur apparaîtront ici.',
                      )
                    : DividedColumn(
                        children: [
                          for (final d in deliveries.take(10))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('#${d.orderReference} • ${d.pickupName}'),
                              subtitle: Text(
                                '${d.customerName} • ${Formatters.dateTime(d.createdAt)}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.price(d.earnings),
                                    style: context.text.titleSmall,
                                  ),
                                  deliveryStatusChip(d.status),
                                ],
                              ),
                              onTap: () => context.go(BackRoutes.order(d.orderId)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.courier});

  final Courier courier;

  @override
  Widget build(BuildContext context) {
    final c = courier;
    final color = courierColor(c.status);
    return AppCard(
      child: Row(
        children: [
          Stack(
            children: [
              Avatar(name: c.fullName, imageUrl: c.avatarUrl, size: 76)
                  .animate()
                  .scaleXY(begin: 0.7, curve: Curves.easeOutBack),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName, style: context.text.titleLarge),
                Text(
                  '${c.vehicle.label} • ${c.zone}',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    courierStatusChip(c.status),
                    documentStatusChip(c.documentStatus),
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

/// Justificatifs : liste et validation globale.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.courier});

  final Courier courier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = courier;
    return SectionCard(
      title: 'Justificatifs',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final doc in c.documents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _DocumentThumb(imageData: doc.imageData),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.type.label, style: context.text.titleSmall),
                        Text(
                          'Envoyé le ${Formatters.date(doc.uploadedAt)}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  documentStatusChip(doc.status),
                ],
              ),
            ),
          if (c.documentStatus != DocumentStatus.approved) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                if (c.documentStatus == DocumentStatus.pending) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => reviewCourierDocuments(
                        context,
                        ref,
                        c,
                        DocumentStatus.rejected,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => reviewCourierDocuments(
                      context,
                      ref,
                      c,
                      DocumentStatus.approved,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('Tout valider'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentDelivery extends ConsumerWidget {
  const _CurrentDelivery({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = delivery;
    final next = nextDeliveryStatus(d.status);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded, color: Colors.white)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveX(begin: -3, end: 3, duration: 700.ms),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Course en cours • #${d.orderReference}',
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                d.status.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            '${d.pickupName} → ${d.dropoffAddress}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: () => updateDeliveryStatus(context, ref, d, next),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: Text(deliveryStepAction(next)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.imageData});

  final String? imageData;

  Uint8List? get _bytes {
    final data = imageData;
    if (data == null || data.isEmpty) return null;
    final payload = data.contains(',') ? data.split(',').last : data;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: bytes == null
          ? Container(
              width: 56,
              height: 56,
              color: context.palette.surfaceMuted,
              child: Icon(
                Icons.hide_image_outlined,
                color: context.palette.textSecondary,
              ),
            )
          : Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
    );
    if (bytes == null) return thumb;
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(child: Image.memory(bytes)),
        ),
      ),
      child: thumb,
    );
  }
}
