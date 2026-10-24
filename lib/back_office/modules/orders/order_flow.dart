import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../shared/models/models.dart';
import 'orders_controller.dart';

// =============================================================================
// Cycle de vie d'une commande côté back office : étape suivante, annulation
// et remboursement (partagé par le tableau, la fiche et la cuisine).
// =============================================================================

/// Étape suivante d'une commande, selon le rôle. Le restaurateur s'arrête à
/// « Prête » (le livreur prend le relais) ; l'admin peut aller jusqu'au bout.
OrderStatus? nextOrderStatus(OrderStatus status, UserRole? role) {
  final next = switch (status) {
    OrderStatus.pending => OrderStatus.accepted,
    OrderStatus.accepted => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.ready,
    OrderStatus.ready => OrderStatus.delivering,
    OrderStatus.delivering => OrderStatus.delivered,
    _ => null,
  };
  if (role == UserRole.restaurant &&
      next != null &&
      next.index > OrderStatus.ready.index) {
    return null;
  }
  return next;
}

/// Libellé du bouton qui mène à [next].
String nextStatusAction(OrderStatus next) => switch (next) {
  OrderStatus.accepted => 'Accepter',
  OrderStatus.preparing => 'Lancer la préparation',
  OrderStatus.ready => 'Marquer prête',
  OrderStatus.delivering => 'Remettre au livreur',
  OrderStatus.delivered => 'Marquer livrée',
  _ => next.label,
};

IconData nextStatusIcon(OrderStatus next) => switch (next) {
  OrderStatus.accepted => Icons.check_rounded,
  OrderStatus.preparing => Icons.soup_kitchen_rounded,
  OrderStatus.ready => Icons.room_service_rounded,
  OrderStatus.delivering => Icons.delivery_dining_rounded,
  OrderStatus.delivered => Icons.task_alt_rounded,
  _ => Icons.arrow_forward_rounded,
};

bool canCancel(Order order) =>
    order.status.index <= OrderStatus.ready.index;

bool canRefund(Order order, UserRole? role) =>
    Permissions.can(role, Permission.refundOrders) &&
    order.paymentStatus == PaymentStatus.paid &&
    (order.status == OrderStatus.delivered ||
        order.status == OrderStatus.cancelled);

/// Passe la commande à l'étape suivante.
Future<void> advanceOrder(
  BuildContext context,
  WidgetRef ref,
  Order order, {
  OrderStatus? to,
}) async {
  final role = ref.read(authServiceProvider).role;
  final next = to ?? nextOrderStatus(order.status, role);
  if (next == null) return;
  try {
    await ref.read(ordersControllerProvider.notifier).updateStatus(order, next);
    if (context.mounted) {
      AppSnackbar.success(context, '#${order.reference} : ${next.label}');
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Annule la commande après avoir choisi un motif.
Future<void> cancelOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _CancelDialog(order: order),
  );
  if (reason == null) return;
  try {
    await ref.read(ordersControllerProvider.notifier).cancel(order, reason);
    if (context.mounted) {
      AppSnackbar.success(context, 'Commande #${order.reference} annulée');
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Rembourse le client (admin).
Future<void> refundOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final confirmed = await ConfirmDeleteDialog.show(
    context,
    title: 'Rembourser #${order.reference} ?',
    message: 'Le client sera remboursé du montant total de la commande.',
    confirmLabel: 'Rembourser',
    icon: Icons.currency_exchange_rounded,
  );
  if (!confirmed) return;
  try {
    await ref.read(ordersControllerProvider.notifier).refund(order);
    if (context.mounted) {
      AppSnackbar.success(context, 'Remboursement effectué');
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.order});

  final Order order;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = [
    'Produit indisponible',
    'Restaurant trop chargé',
    'Restaurant fermé',
    'Demande du client',
    'Adresse hors zone de livraison',
  ];
  String _reason = _reasons.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 36),
      title: Text('Annuler #${widget.order.reference} ?'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in _reasons)
              RadioListTile<String>(
                value: r,
                groupValue: _reason,
                dense: true,
                title: Text(r),
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, _reason),
          child: const Text('Annuler la commande'),
        ),
      ],
    );
  }
}
