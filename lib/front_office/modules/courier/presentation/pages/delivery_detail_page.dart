import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/city_map.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../providers/courier_providers.dart';
import '../widgets/delivery_widgets.dart';

/// Détail d'une course : plan, trajet, étapes, client et action suivante.
class DeliveryDetailPage extends ConsumerWidget {
  const DeliveryDetailPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(myDeliveriesProvider);
    final delivery = deliveries.value
        ?.where((d) => d.id == deliveryId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: delivery == null
            ? (deliveries.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const EmptyState(
                      icon: Icons.route_rounded,
                      title: 'Course introuvable',
                      message: 'Cette course n’est plus disponible.',
                    ))
            : _DetailView(delivery: delivery),
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.delivery});

  final Delivery delivery;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dash = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _dash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final next = nextStepLabel(d.status);
    final steps = [
      (DeliveryStatus.assigned, 'Assignée', d.assignedAt),
      (DeliveryStatus.pickedUp, 'Récupérée au restaurant', d.pickedUpAt),
      (DeliveryStatus.inTransit, 'En route vers le client', null),
      (DeliveryStatus.delivered, 'Livrée', d.deliveredAt),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      children:
          [
                Row(
                  children: [
                    Expanded(child: PageTitle('Course #${d.orderReference}')),
                    deliveryStatusChip(d.status),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  child: SizedBox(
                    height: 190,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final from = Offset(c.maxWidth * 0.2, c.maxHeight * 0.3);
                        final to = Offset(c.maxWidth * 0.8, c.maxHeight * 0.72);
                        return AnimatedBuilder(
                          animation: _dash,
                          builder: (context, _) => Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CityMapPainter(
                                    dark: context.isDark,
                                    routes: [(from, to)],
                                    dash: _dash.value,
                                  ),
                                ),
                              ),
                              _pin(from, Icons.storefront_rounded, AppColors.primary),
                              _pin(to, Icons.location_on_rounded, AppColors.success),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Column(
                    children: [
                      RouteSummary(delivery: d),
                      const Divider(height: 28),
                      Row(
                        children: [
                          _Figure(
                            label: 'Distance',
                            value: Formatters.distance(d.distanceKm),
                          ),
                          _Figure(
                            label: 'Durée',
                            value: '~${d.estimatedMinutes} min',
                          ),
                          _Figure(
                            label: 'Gain',
                            value: Formatters.price(d.earnings),
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Étapes', style: context.text.titleMedium),
                      const SizedBox(height: AppSizes.sm),
                      for (final (status, label, at) in steps)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                d.status.index >= status.index &&
                                        d.status != DeliveryStatus.cancelled
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color:
                                    d.status.index >= status.index &&
                                        d.status != DeliveryStatus.cancelled
                                    ? AppColors.success
                                    : context.palette.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(label)),
                              if (at != null)
                                Text(
                                  Formatters.time(at),
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                if (d.status.isActive)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Client : ${d.customerName}',
                          style: context.text.titleSmall,
                        ),
                      ),
                      CircleIconButton(
                        icon: Icons.call_rounded,
                        tooltip: 'Appeler le client',
                        onTap: () => AppSnackbar.info(
                          context,
                          'Appel de ${d.customerName} (démo).',
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleIconButton(
                        icon: Icons.navigation_rounded,
                        tooltip: 'Itinéraire',
                        backgroundColor: AppColors.primary,
                        iconColor: Colors.white,
                        onTap: () => AppSnackbar.info(
                          context,
                          'Ouverture du GPS (démo).',
                        ),
                      ),
                    ],
                  ),
                if (next != null) ...[
                  const SizedBox(height: AppSizes.lg),
                  PrimaryButton(
                    label: next,
                    icon: Icons.check_rounded,
                    onPressed: () => advanceDelivery(context, ref, d),
                  ),
                ],
              ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.05, end: 0),
    );
  }

  Widget _pin(Offset at, IconData icon, Color color) => Positioned(
    left: at.dx - 18,
    top: at.dy - 18,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: context.text.titleMedium?.copyWith(color: color)),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
