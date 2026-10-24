import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../catalog/data/catalog_mock_data.dart';
import '../../../communication/communication_routes.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../data/admin_mock_data.dart';
import '../widgets/stat_card.dart';
import '../widgets/weekly_chart.dart';

/// Tableau de bord administrateur (données fictives).
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = OrdersController.instance;
    final topRestaurants = [...CatalogMockData.restaurants]
      ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    final maxReviews = topRestaurants.first.reviewCount;
    final columns = context.screenSize.width > 600 ? 4 : 2;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Tableau de bord'),
      ),
      body: ListenableBuilder(
        listenable: orders,
        builder: (context, _) {
          final recent = [
            ...orders.activeOrders,
            ...orders.pastOrders,
          ].take(5).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.sm,
              AppSizes.pagePadding,
              AppSizes.xl,
            ),
            children: [
              Text(
                "Aujourd'hui • ${Formatters.date(DateTime.now())}",
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Hauteur fixe (suit la taille du texte) : le contenu de la
                // carte tient aussi sur les petits écrans.
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(136),
                ),
                children: [
                  for (final (i, stat) in AdminMockData.stats.indexed)
                    StatCard(stat: stat)
                        .animate(delay: (80 * i).ms)
                        .fadeIn(duration: 400.ms)
                        .scaleXY(
                          begin: 0.85,
                          end: 1,
                          curve: Curves.easeOutBack,
                        ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              const WeeklyChart(
                    values: AdminMockData.weeklyOrders,
                    labels: AdminMockData.weekDays,
                  )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSizes.lg),
              const _ModerationShortcut()
                  .animate(delay: 350.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSizes.lg),
              const SectionHeader(
                title: 'Commandes récentes',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              for (final (i, order) in recent.indexed)
                Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Pressable(
                        onTap: () =>
                            context.push(AppRoutes.trackingOf(order.id)),
                        scale: 0.98,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            border: Border.all(color: context.palette.border),
                          ),
                          child: Row(
                            children: [
                              AppNetworkImage(
                                order.imageUrl,
                                width: 44,
                                height: 44,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${order.displayNumber} • ${order.title}',
                                      style: context.text.titleSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${Formatters.price(order.total)} • ${Formatters.relative(order.createdAt)}',
                                      style: context.text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              OrderStatusChip(status: order.status),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate(delay: (400 + 60 * i).ms)
                    .fadeIn()
                    .slideX(begin: 0.1, end: 0),
              const SizedBox(height: AppSizes.md),
              const SectionHeader(
                title: 'Top restaurants',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              for (final (i, r) in topRestaurants.take(5).indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Pressable(
                    onTap: () => context.push(
                      AppRoutes.restaurantDetail(r.id, hero: 'admin'),
                    ),
                    scale: 0.98,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#${i + 1}',
                            style: context.text.titleSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.name,
                                      style: context.text.titleSmall,
                                    ),
                                  ),
                                  Text(
                                    '${r.reviewCount} avis',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: r.reviewCount / maxReviews,
                                  ),
                                  duration: Duration(
                                    milliseconds: 800 + i * 120,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) =>
                                      LinearProgressIndicator(
                                        value: value,
                                        minHeight: 7,
                                        backgroundColor: context.palette.border,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Accès à la modération des avis (module 5).
class _ModerationShortcut extends StatelessWidget {
  const _ModerationShortcut();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(CommunicationRoutes.moderation),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modération des avis',
                    style: context.text.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Avis en attente, signalements, réponses',
                    style: context.text.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
