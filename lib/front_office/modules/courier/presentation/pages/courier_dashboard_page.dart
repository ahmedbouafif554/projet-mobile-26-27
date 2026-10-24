import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/animated_counter.dart';
import '../../../../../core/widgets/app_charts.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../providers/courier_providers.dart';
import '../widgets/delivery_widgets.dart';

/// Tableau de bord du livreur : disponibilité, chiffres du jour, course en
/// cours, gains de la semaine.
class CourierDashboardPage extends ConsumerWidget {
  const CourierDashboardPage({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool online) async {
    try {
      await ref.read(myCourierProvider.notifier).setOnline(online);
      if (context.mounted) {
        AppSnackbar.success(
          context,
          online
              ? 'Vous êtes en ligne : les courses arrivent !'
              : 'Vous êtes hors ligne',
        );
      }
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).user;
    final courier = ref.watch(myCourierProvider).value;
    final deliveries = ref.watch(myDeliveriesProvider).value ?? const [];
    final available = ref.watch(availableDeliveriesProvider).value ?? const [];
    final current = deliveries.where((d) => d.status.isActive).firstOrNull;
    final today = deliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.delivered &&
              isToday(d.deliveredAt ?? d.createdAt),
        )
        .toList();
    final todayEarnings = today.fold<double>(0, (s, d) => s + d.earnings);
    final todayKm = today.fold<double>(0, (s, d) => s + d.distanceKm);
    final week = earningsByDay(deliveries);
    final online = courier?.status.isOnline ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref
              ..invalidate(myCourierProvider)
              ..invalidate(availableDeliveriesProvider);
            await ref.read(myDeliveriesProvider.future);
          },
          child: ListView(
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
                          Avatar(
                            name: user?.fullName ?? '',
                            imageUrl: user?.avatarUrl,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour ${user?.firstName ?? ''} 👋',
                                  style: context.text.titleLarge,
                                ),
                                Text(
                                  courier == null
                                      ? ''
                                      : '${courier.vehicle.label} • ${courier.zone}',
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _OnlineSwitch(
                        status: courier?.status ?? CourierStatus.offline,
                        onChanged: (v) => _toggle(context, ref, v),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          _TodayStat(
                            icon: Icons.inventory_2_rounded,
                            label: 'Courses',
                            value: today.length,
                            format: Formatters.count,
                          ),
                          const SizedBox(width: AppSizes.sm + 4),
                          _TodayStat(
                            icon: Icons.euro_rounded,
                            label: 'Gains',
                            value: todayEarnings,
                            format: Formatters.price,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSizes.sm + 4),
                          _TodayStat(
                            icon: Icons.route_rounded,
                            label: 'Distance',
                            value: todayKm,
                            format: Formatters.distance,
                            color: AppColors.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.lg),
                      if (current != null) ...[
                        Text('Course en cours', style: context.text.titleLarge),
                        const SizedBox(height: AppSizes.sm),
                        DeliveryCard(
                          delivery: current,
                          onTap: () => context.push(
                            FrontRoutes.courierDelivery(current.id),
                          ),
                          actions: nextStepLabel(current.status) == null
                              ? null
                              : PrimaryButton(
                                  label: nextStepLabel(current.status)!,
                                  height: 48,
                                  onPressed: () =>
                                      advanceDelivery(context, ref, current),
                                ),
                        ),
                        const SizedBox(height: AppSizes.lg),
                      ] else if (online)
                        _OffersBanner(count: available.length),
                      if (current == null && online)
                        const SizedBox(height: AppSizes.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Gains de la semaine',
                              style: context.text.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go(FrontRoutes.courierEarnings),
                            child: const Text('Détails'),
                          ),
                        ],
                      ),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: AppBarChart(
                          bars: [
                            for (final (day, total) in week)
                              ChartBar(
                                label: Formatters.weekday(day),
                                value: total,
                              ),
                          ],
                          formatValue: Formatters.priceShort,
                          color: AppColors.success,
                        ),
                      ),
                    ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.06, end: 0),
          ),
        ),
      ),
    );
  }
}

/// Grand interrupteur « En ligne / Hors ligne ».
class _OnlineSwitch extends StatelessWidget {
  const _OnlineSwitch({required this.status, required this.onChanged});

  final CourierStatus status;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final online = status.isOnline;
    final busy = status == CourierStatus.busy;
    return AnimatedContainer(
      duration: AppDurations.medium,
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        gradient: online
            ? const LinearGradient(
                colors: [Color(0xFF34D399), AppColors.success],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: online ? null : context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: online
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: online ? Colors.white : context.palette.textSecondary,
                  shape: BoxShape.circle,
                ),
              )
              .animate(
                onPlay: (c) => online ? c.repeat(reverse: true) : c.stop(),
                key: ValueKey(online),
              )
              .scaleXY(begin: 0.8, end: 1.25, duration: 700.ms),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  busy
                      ? 'En course'
                      : online
                      ? 'En ligne'
                      : 'Hors ligne',
                  style: context.text.titleLarge?.copyWith(
                    color: online ? Colors.white : null,
                  ),
                ),
                Text(
                  busy
                      ? 'Terminez votre course pour vous déconnecter.'
                      : online
                      ? 'Vous recevez des propositions de courses.'
                      : 'Passez en ligne pour recevoir des courses.',
                  style: context.text.bodySmall?.copyWith(
                    color: online
                        ? Colors.white.withValues(alpha: 0.9)
                        : context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Pendant une course, l'interrupteur laisse place à une icône.
          if (busy)
            const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 32,
            )
          else
            Switch(
              value: online,
              onChanged: onChanged,
              activeTrackColor: Colors.white,
              activeColor: AppColors.success,
            ),
        ],
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final num value;
  final String Function(num) format;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedCounter(
                value: value,
                format: format,
                style: context.text.titleMedium,
              ),
            ),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersBanner extends StatelessWidget {
  const _OffersBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        onTap: () => context.go(FrontRoutes.courierDeliveries),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.primary,
              )
                  .animate(onPlay: (c) => c.repeat())
                  .shake(hz: 2, rotation: 0.1, duration: 900.ms)
                  .then(delay: 1200.ms),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 0
                      ? 'Aucune course pour le moment, restez à l’écoute.'
                      : '$count course${count > 1 ? 's' : ''} disponible${count > 1 ? 's' : ''} près de vous',
                  style: context.text.titleSmall,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
