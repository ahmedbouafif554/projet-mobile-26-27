import 'package:flutter/material.dart';

import '../../core/widgets/status_chip.dart';
import '../models/models.dart';

// =============================================================================
// Pastilles de statut des entités partagées : le même statut a la même
// couleur dans le front office et dans le back office.
// =============================================================================

StatusTone orderTone(OrderStatus status) => switch (status) {
  OrderStatus.pending => StatusTone.info,
  OrderStatus.accepted || OrderStatus.preparing => StatusTone.warning,
  OrderStatus.ready || OrderStatus.delivering => StatusTone.primary,
  OrderStatus.delivered => StatusTone.success,
  OrderStatus.cancelled => StatusTone.danger,
  OrderStatus.refunded => StatusTone.neutral,
};

StatusChip orderStatusChip(OrderStatus status, {bool dense = false}) =>
    StatusChip(label: status.label, tone: orderTone(status), dense: dense);

StatusChip userStatusChip(UserStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    UserStatus.active => StatusTone.success,
    UserStatus.blocked => StatusTone.danger,
    UserStatus.pending => StatusTone.warning,
  },
);

StatusChip userRoleChip(UserRole role) => StatusChip(
  label: role.label,
  icon: switch (role) {
    UserRole.client => Icons.person_rounded,
    UserRole.courier => Icons.delivery_dining_rounded,
    UserRole.restaurant => Icons.storefront_rounded,
    UserRole.admin => Icons.admin_panel_settings_rounded,
  },
  tone: switch (role) {
    UserRole.client => StatusTone.info,
    UserRole.courier => StatusTone.primary,
    UserRole.restaurant => StatusTone.warning,
    UserRole.admin => StatusTone.neutral,
  },
);

StatusChip restaurantStatusChip(RestaurantStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    RestaurantStatus.pending => StatusTone.warning,
    RestaurantStatus.approved => StatusTone.success,
    RestaurantStatus.rejected => StatusTone.danger,
    RestaurantStatus.suspended => StatusTone.neutral,
  },
);

StatusChip deliveryStatusChip(DeliveryStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    DeliveryStatus.waiting => StatusTone.warning,
    DeliveryStatus.assigned || DeliveryStatus.pickedUp => StatusTone.info,
    DeliveryStatus.inTransit => StatusTone.primary,
    DeliveryStatus.delivered => StatusTone.success,
    DeliveryStatus.cancelled => StatusTone.danger,
  },
);

StatusChip courierStatusChip(CourierStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    CourierStatus.available => StatusTone.success,
    CourierStatus.busy => StatusTone.primary,
    CourierStatus.offline => StatusTone.neutral,
  },
);

StatusChip documentStatusChip(DocumentStatus status) => StatusChip(
  label: status.label,
  icon: switch (status) {
    DocumentStatus.pending => Icons.hourglass_top_rounded,
    DocumentStatus.approved => Icons.verified_rounded,
    DocumentStatus.rejected => Icons.block_rounded,
  },
  tone: switch (status) {
    DocumentStatus.pending => StatusTone.warning,
    DocumentStatus.approved => StatusTone.success,
    DocumentStatus.rejected => StatusTone.danger,
  },
);

StatusChip reviewStatusChip(ReviewStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    ReviewStatus.pending => StatusTone.warning,
    ReviewStatus.approved => StatusTone.success,
    ReviewStatus.rejected => StatusTone.danger,
  },
);

StatusChip campaignStatusChip(CampaignStatus status) => StatusChip(
  label: status.label,
  tone: switch (status) {
    CampaignStatus.draft => StatusTone.neutral,
    CampaignStatus.scheduled => StatusTone.info,
    CampaignStatus.sent => StatusTone.success,
  },
);
