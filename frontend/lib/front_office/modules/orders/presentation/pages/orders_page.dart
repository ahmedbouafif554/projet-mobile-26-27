import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../../../router/front_routes.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/orders_providers.dart';
import '../widgets/order_widgets.dart';

/// Commandes du client (onglet) : en cours et historique.
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final all = orders.value ?? const <Order>[];
    final active = all.where((o) => o.status.isActive).toList();
    final past = all.where((o) => !o.status.isActive).toList();

    Widget list(List<Order> items, {required bool current}) {
      if (orders.isLoading && orders.value == null) {
        return ShimmerScope(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSizes.md),
                  child: SkeletonBox(height: 150, radius: AppSizes.radiusLg),
                ),
            ],
          ),
        );
      }
      if (items.isEmpty) {
        return EmptyState(
          icon: current ? Icons.delivery_dining_rounded : Icons.history_rounded,
          title: current ? 'Aucune commande en cours' : 'Pas encore d’historique',
          message: current
              ? 'Vos commandes en préparation et en livraison apparaîtront ici.'
              : 'Vos commandes passées apparaîtront ici.',
          actionLabel: 'Commander',
          onAction: () => context.go(FrontRoutes.explore),
        );
      }
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myOrdersProvider);
          await ref.read(myOrdersProvider.future);
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
          itemBuilder: (context, i) => OrderCard(order: items[i])
              .animate(delay: (50 * (i % 6)).ms)
              .fadeIn()
              .slideY(begin: 0.06, end: 0),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  AppSizes.sm,
                ),
                child: PageTitle('Mes commandes'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      boxShadow: context.palette.softShadow,
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: context.palette.textSecondary,
                    labelStyle: context.text.labelLarge,
                    tabs: [
                      Tab(text: 'En cours (${active.length})'),
                      Tab(text: 'Historique (${past.length})'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    list(active, current: true),
                    list(past, current: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'une commande : restaurant, statut, articles, total et actions.
class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final reviewed =
        ref.watch(myReviewsProvider).value?.any((r) => r.orderId == o.id) ??
        false;
    return SurfaceCard(
      onTap: () => context.push(FrontRoutes.order(o.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      '#${o.reference} • ${Formatters.dateTime(o.createdAt)}',
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              orderStatusChip(o.status, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            o.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.price(o.total),
                  style: context.text.titleMedium,
                ),
              ),
              if (o.status.isActive)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () =>
                      context.push(FrontRoutes.orderTracking(o.id)),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Suivre'),
                )
              else ...[
                if (o.status == OrderStatus.delivered && !reviewed)
                  TextButton.icon(
                    onPressed: () =>
                        context.push(FrontRoutes.writeReview(o.id)),
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: const Text('Noter'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => reorder(context, ref, o),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Recommander'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Remet les articles dans le panier puis ouvre le panier.
Future<void> reorder(BuildContext context, WidgetRef ref, Order order) async {
  try {
    await ref.read(myOrdersProvider.notifier).reorder(order);
    if (!context.mounted) return;
    AppSnackbar.success(context, 'Articles ajoutés au panier');
    context.go(FrontRoutes.cart);
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}
