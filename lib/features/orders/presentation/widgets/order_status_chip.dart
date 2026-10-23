import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../models/order.dart';

/// Couleur associée à chaque statut de commande.
Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.confirmed => AppColors.info,
  OrderStatus.preparing => AppColors.warning,
  OrderStatus.onTheWay => AppColors.primary,
  OrderStatus.delivered => AppColors.success,
  OrderStatus.cancelled => AppColors.error,
};

/// Pastille de statut ; le point clignote pour les commandes en cours.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);

    Widget dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (status.isActive) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.3, end: 1, duration: 700.ms);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            status.label,
            style: context.text.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
