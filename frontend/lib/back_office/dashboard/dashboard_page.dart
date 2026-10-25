import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_charts.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/chart_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../core/widgets/stat_card.dart';
import '../../shared/models/user.dart';
import '../modules/orders/orders_controller.dart';
import '../router/back_routes.dart';
import '../shared/bo_widgets.dart';
import '../shell/back_alerts.dart';
import '../shell/bo_page.dart';
import 'dashboard_provider.dart';

/// Tableau de bord : indicateurs, graphiques, alertes et dernières commandes.
/// L'admin voit toute la plateforme, un restaurateur son restaurant.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null pendant la déconnexion, avant la redirection vers la connexion.
    final user = ref.watch(authServiceProvider).user;
    if (user == null) return const SizedBox.shrink();
    final isAdmin = user.role == UserRole.admin;
    final data = ref.watch(dashboardProvider);

    return BoPage(
      title: 'Tableau de bord',
      subtitle: isAdmin
          ? 'Bonjour ${user.firstName} 👋 Voici l’activité de la plateforme aujourd’hui.'
          : 'Bonjour ${user.firstName} 👋 Voici l’activité de votre restaurant.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(ordersControllerProvider),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
      ],
      children: [
        AsyncValueView(
          value: data,
          onRetry: () => ref.invalidate(dashboardProvider),
          loading: const _DashboardSkeleton(),
          data: (d) => _DashboardContent(data: d, role: user.role),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.role});

  final DashboardData data;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final total = data.statusSlices.fold<double>(0, (s, e) => s + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          children: [
            for (final kpi in data.kpis)
              StatCard(
                label: kpi.label,
                value: kpi.value,
                icon: kpi.icon,
                format: kpi.format,
                color: kpi.color,
                trend: kpi.trend,
                caption: kpi.caption,
                onTap: kpi.route == null ? null : () => context.go(kpi.route!),
              ),
          ],
        ),
        boGap,
        SplitRow(
          left: ChartCard(
            title: 'Ventes sur 7 jours',
            subtitle: 'Hors commandes annulées et remboursées',
            child: AppLineChart(values: data.sales, labels: data.days),
          ),
          right: ChartCard(
            title: 'Commandes par statut',
            subtitle: '${Formatters.count(total)} commandes au total',
            child: AppPieChart(
              slices: data.statusSlices,
              centerLabel: Formatters.count(total),
            ),
          ),
        ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
        boGap,
        SplitRow(
          left: ChartCard(
            title: data.barsTitle,
            subtitle: data.barsSubtitle,
            height: 230,
            child: data.bars.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.bar_chart_rounded,
                    title: 'Pas encore de ventes',
                    message: 'Les statistiques apparaîtront ici.',
                  )
                : AppBarChart(bars: data.bars, formatValue: data.barsFormat),
          ),
          right: _AlertsCard(role: role),
        ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
        boGap,
        SectionCard(
          title: 'Dernières commandes',
          icon: Icons.receipt_long_rounded,
          trailing: TextButton.icon(
            onPressed: () => context.go(BackRoutes.orders),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Tout voir'),
          ),
          child: data.latestOrders.isEmpty
              ? const EmptyState(
                  compact: true,
                  title: 'Aucune commande',
                  message: 'Les nouvelles commandes apparaîtront ici.',
                )
              : DividedColumn(
                  children: [
                    for (final order in data.latestOrders)
                      OrderListTile(
                        order: order,
                        showRestaurant: role == UserRole.admin,
                      ),
                  ],
                ),
        ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}

/// Éléments à traiter (mêmes compteurs que la cloche et le menu).
class _AlertsCard extends ConsumerWidget {
  const _AlertsCard({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = watchAlerts(ref, role);
    return SectionCard(
      title: 'À traiter',
      icon: Icons.notifications_active_rounded,
      subtitle: alerts.isEmpty
          ? null
          : '${alerts.fold(0, (s, a) => s + a.count)} éléments en attente',
      child: SizedBox(
        height: 230,
        child: alerts.isEmpty
            ? const EmptyState(
                compact: true,
                icon: Icons.check_rounded,
                title: 'Tout est à jour',
                message: 'Aucune action en attente. Beau travail !',
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final (i, alert) in alerts.indexed)
                    _AlertTile(alert: alert)
                        .animate(delay: (60 * i).ms)
                        .fadeIn()
                        .slideX(begin: 0.08, end: 0),
                ],
              ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final BoAlert alert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: alert.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: InkWell(
          onTap: () => context.go(alert.route),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: alert.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alert.icon, color: alert.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alertLabel(alert),
                    style: context.text.titleSmall,
                  ),
                ),
                Text(
                  'Traiter',
                  style: context.text.labelMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 230).floor().clamp(1, 4);
              final width =
                  (constraints.maxWidth - AppSizes.md * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSizes.md,
                runSpacing: AppSizes.md,
                children: [
                  for (var i = 0; i < 4; i++)
                    SkeletonBox(
                      width: width,
                      height: 132,
                      radius: AppSizes.radiusLg,
                    ),
                ],
              );
            },
          ),
          boGap,
          const SkeletonBox(height: 320, radius: AppSizes.radiusLg),
          boGap,
          const SkeletonBox(height: 300, radius: AppSizes.radiusLg),
        ],
      ),
    );
  }
}
