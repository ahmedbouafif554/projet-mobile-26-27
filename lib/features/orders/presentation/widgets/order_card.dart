import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/order.dart';
import '../controllers/cart_controller.dart';
import '../controllers/orders_controller.dart';
import 'order_status_chip.dart';

/// En-tête commun : photo, titre, date et statut.
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppNetworkImage(
          order.imageUrl,
          width: 56,
          height: 56,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          fallbackIcon: order.type == OrderType.parcel
              ? Icons.inventory_2_rounded
              : Icons.restaurant_rounded,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.title,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${order.displayNumber} • ${Formatters.dateTime(order.createdAt)}',
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OrderStatusChip(status: order.status),
      ],
    );
  }
}

/// Carte d'une commande en cours, avec progression et bouton de suivi.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final step = OrderStatus.values.indexOf(order.status);
    final eta = order.createdAt.add(Duration(minutes: order.etaMinutes));

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderHeader(order: order),
          const SizedBox(height: AppSizes.md),
          // Progression en 4 segments
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child:
                      FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: i <= step ? 1 : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          )
                          .animate(delay: (200 * i).ms)
                          .scaleX(
                            begin: 0,
                            end: 1,
                            alignment: Alignment.centerLeft,
                            duration: 500.ms,
                          ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Arrivée estimée vers ${Formatters.time(eta)}',
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          PrimaryButton(
            label: 'Suivre la commande',
            icon: Icons.map_rounded,
            height: 50,
            onPressed: () => context.push(AppRoutes.trackingOf(order.id)),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une commande passée avec bouton « Re-commander ».
class PastOrderCard extends StatelessWidget {
  const PastOrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(AppRoutes.trackingOf(order.id)),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderHeader(order: order),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Text(
              order.summary,
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  Formatters.price(order.total),
                  style: context.text.titleMedium,
                ),
                const Spacer(),
                if (order.type == OrderType.food) _ReorderButton(order: order),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Re-commander » : l'icône tourne, se change en coche,
/// puis ouvre le panier rempli.
class _ReorderButton extends StatefulWidget {
  const _ReorderButton({required this.order});

  final Order order;

  @override
  State<_ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends State<_ReorderButton> {
  bool _done = false;
  Timer? _timer;

  void _reorder() {
    if (_done) return;
    OrdersController.instance.reorder(widget.order, CartController.instance);
    setState(() => _done = true);
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      context.push(AppRoutes.cart);
      setState(() => _done = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _done ? AppColors.success : AppColors.primary;

    return Pressable(
      onTap: _reorder,
      scale: 0.92,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _done
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('done'),
                      size: 18,
                      color: color,
                    )
                  : Icon(
                      Icons.replay_rounded,
                      key: const ValueKey('reorder'),
                      size: 18,
                      color: color,
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              _done ? 'Ajouté !' : 'Re-commander',
              style: context.text.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
