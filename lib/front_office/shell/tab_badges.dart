import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../shared/models/models.dart';
import '../modules/communication/providers/communication_providers.dart';
import '../modules/courier/providers/courier_providers.dart';
import '../modules/orders/providers/cart_controller.dart';
import '../modules/orders/providers/orders_providers.dart';

// =============================================================================
// Compteurs des onglets, lus directement sur les contrôleurs des modules :
// ajouter au panier, accepter une course ou lire un message met la pastille
// à jour immédiatement.
//
// Important (Riverpod 3) : les widgets sont mis en pause quand ils ne sont
// pas visibles (onglet inactif, page recouverte). La barre utilise donc un
// `select` sur le contrôleur, sans Provider intermédiaire qui le « watch » :
// à la reprise, celui-ci serait invalidé pendant la construction des widgets
// (erreur « setState() called during build »).
// =============================================================================

typedef TabBadge = ProviderListenable<AsyncValue<int>>;

/// Articles dans le panier (onglet Panier du client).
final TabBadge cartCountBadge = cartProvider.select(
  (cart) => cart.whenData(
    (items) => items.fold<int>(0, (sum, i) => sum + i.quantity),
  ),
);

/// Commandes en cours du client (onglet Commandes).
final TabBadge activeOrdersBadge = myOrdersProvider.select(
  (orders) => orders.whenData(
    (list) => list.where((o) => o.status.isActive).length,
  ),
);

/// Courses proposées au livreur (onglet Livraisons).
final TabBadge availableDeliveriesBadge = availableDeliveriesProvider.select(
  (deliveries) => deliveries.whenData((list) => list.length),
);

/// Messages non lus (onglet Messages du livreur).
final TabBadge unreadMessagesBadge = myChatsProvider.select(
  (chats) => chats.whenData(
    (list) => list.fold<int>(0, (sum, Chat c) => sum + c.unreadCount),
  ),
);
