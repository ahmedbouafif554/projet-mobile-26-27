import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../catalog/presentation/widgets/catalog_shimmers.dart';
import '../../models/order.dart';
import '../controllers/orders_controller.dart';
import '../widgets/order_card.dart';

/// Onglet Commandes : commandes en cours et historique.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = OrdersController.instance;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  AppSizes.md,
                ),
                child: const PageTitle('Mes commandes'),
              ),
              // Sélecteur segmenté animé
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    boxShadow: context.palette.softShadow,
                  ),
                  labelColor: context.colors.onSurface,
                  splashBorderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  tabs: const [
                    Tab(text: 'En cours', height: 42),
                    Tab(text: 'Historique', height: 42),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppDurations.medium,
                  child: _loading
                      ? const RestaurantListShimmer(key: ValueKey('shimmer'))
                      : ListenableBuilder(
                          key: const ValueKey('content'),
                          listenable: orders,
                          builder: (context, _) => TabBarView(
                            children: [
                              _OrdersList(
                                orders: orders.activeOrders,
                                active: true,
                              ),
                              _OrdersList(
                                orders: orders.pastOrders,
                                active: false,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.active});

  final List<Order> orders;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: active
            ? Icons.delivery_dining_outlined
            : Icons.receipt_long_outlined,
        title: active ? 'Aucune commande en cours' : 'Aucune commande passée',
        message: active
            ? 'Vos commandes en préparation et en livraison apparaîtront ici.'
            : 'Votre historique de commandes apparaîtra ici.',
        actionLabel: 'Commander maintenant',
        onAction: () => context.go(AppRoutes.home),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (context, i) {
        final order = orders[i];
        final card = active
            ? ActiveOrderCard(order: order)
            : PastOrderCard(order: order);
        return card
            .animate(key: ValueKey(order.id), delay: (70 * i.clamp(0, 6)).ms)
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }
}
