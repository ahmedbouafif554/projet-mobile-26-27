import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/animated_counter.dart';
import '../../../../../core/widgets/app_charts.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../shared/models/models.dart';
import '../../providers/courier_providers.dart';

/// Gains du livreur : total, graphique des 7 derniers jours et courses
/// rémunérées.
class CourierEarningsPage extends ConsumerWidget {
  const CourierEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courier = ref.watch(myCourierProvider).value;
    final deliveries = (ref.watch(myDeliveriesProvider).value ?? const <Delivery>[])
        .where((d) => d.status == DeliveryStatus.delivered)
        .toList();
    final week = earningsByDay(deliveries);
    final weekTotal = week.fold<double>(0, (s, e) => s + e.$2);
    final tips = deliveries.fold<double>(0, (s, d) => s + d.tip);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children:
              [
                    const PageTitle('Mes gains'),
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gains totaux',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          AnimatedCounter(
                            value: courier?.totalEarnings ?? 0,
                            format: Formatters.price,
                            style: context.text.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          Row(
                            children: [
                              _Mini(
                                label: 'Cette semaine',
                                value: Formatters.price(weekTotal),
                              ),
                              _Mini(
                                label: 'Pourboires',
                                value: Formatters.price(tips),
                              ),
                              _Mini(
                                label: 'Courses',
                                value: '${courier?.completedDeliveries ?? 0}',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(46),
                            ),
                            onPressed: () => AppSnackbar.success(
                              context,
                              'Virement demandé : arrivée sous 48 h (démo).',
                            ),
                            icon: const Icon(Icons.account_balance_rounded),
                            label: const Text('Virer sur mon compte'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Text('7 derniers jours', style: context.text.titleLarge),
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      height: 210,
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: AppBarChart(
                        bars: [
                          for (final (day, total) in week)
                            ChartBar(label: Formatters.weekday(day), value: total),
                        ],
                        formatValue: Formatters.priceShort,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Text('Courses rémunérées', style: context.text.titleLarge),
                    const SizedBox(height: AppSizes.sm),
                    if (deliveries.isEmpty)
                      const EmptyState(
                        compact: true,
                        icon: Icons.payments_outlined,
                        title: 'Aucune course livrée',
                        message: 'Vos gains apparaîtront ici.',
                      )
                    else
                      for (final d in deliveries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.success.withValues(
                              alpha: 0.14,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.success,
                            ),
                          ),
                          title: Text('#${d.orderReference} • ${d.pickupName}'),
                          subtitle: Text(
                            Formatters.dateTime(d.deliveredAt ?? d.createdAt),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${Formatters.price(d.earnings)}',
                                style: context.text.titleSmall?.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                              if (d.tip > 0)
                                Text(
                                  'pourboire ${Formatters.price(d.tip)}',
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                  ]
                  .animate(interval: 40.ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
