import 'package:flutter/widgets.dart';

import '../../orders/models/order.dart';

/// Étape affichée dans la frise de suivi de commande.
class TrackingStep {
  const TrackingStep({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final OrderStatus status;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Format de colis proposé à l'envoi.
class ParcelSize {
  const ParcelSize({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.price,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final double price;
}
