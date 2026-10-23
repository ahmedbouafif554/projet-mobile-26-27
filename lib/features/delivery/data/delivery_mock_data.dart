import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../orders/models/order.dart';
import '../models/courier.dart';
import '../models/tracking_step.dart';

/// Fausses données de livraison : livreur, étapes, itinéraire, colis.
class DeliveryMockData {
  DeliveryMockData._();

  static final Courier courier = Courier(
    name: 'Karim B.',
    photoUrl: unsplash('1535713875002-d1d0cf377fde', width: 200),
    rating: 4.9,
    vehicle: 'Scooter électrique',
    plate: 'GH-482-PL',
    deliveries: 1284,
  );

  static const List<TrackingStep> steps = [
    TrackingStep(
      status: OrderStatus.confirmed,
      title: 'Commande confirmée',
      subtitle: 'Le restaurant a bien reçu votre commande',
      icon: Icons.receipt_long_rounded,
    ),
    TrackingStep(
      status: OrderStatus.preparing,
      title: 'En préparation',
      subtitle: 'Vos plats sont préparés avec soin',
      icon: Icons.soup_kitchen_rounded,
    ),
    TrackingStep(
      status: OrderStatus.onTheWay,
      title: 'En route',
      subtitle: 'Votre livreur arrive avec votre commande',
      icon: Icons.delivery_dining_rounded,
    ),
    TrackingStep(
      status: OrderStatus.delivered,
      title: 'Livrée',
      subtitle: 'Bon appétit !',
      icon: Icons.home_rounded,
    ),
  ];

  /// Itinéraire simulé, en unités de grille de la carte
  /// (1 unité = un pâté de maisons = 1/4 de la largeur de l'écran).
  /// Les valeurs entières tombent sur les rues.
  static const List<Offset> route = [
    Offset(1, 3.7),
    Offset(1, 3),
    Offset(2, 3),
    Offset(2, 2),
    Offset(3, 2),
    Offset(3, 1.2),
  ];

  static final List<ParcelSize> parcelSizes = [
    const ParcelSize(
      id: 's',
      label: 'Petit',
      description: 'Enveloppe, clés, documents • jusqu\'à 2 kg',
      icon: Icons.mail_outline_rounded,
      price: 5.90,
    ),
    const ParcelSize(
      id: 'm',
      label: 'Moyen',
      description: 'Boîte à chaussures, sac • jusqu\'à 8 kg',
      icon: Icons.inventory_2_outlined,
      price: 8.90,
    ),
    const ParcelSize(
      id: 'l',
      label: 'Grand',
      description: 'Carton de déménagement • jusqu\'à 20 kg',
      icon: Icons.local_shipping_outlined,
      price: 14.90,
    ),
  ];

  static final String parcelImage = unsplash(
    '1566576721346-d4a3b4eaeb55',
    width: 600,
  );
}
