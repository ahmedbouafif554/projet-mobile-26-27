import '../../core/routes/module_routes.dart';
import 'presentation/pages/parcel_page.dart';

/// Routes du Module 4 — Livraison et livreurs (`/delivery/...`).
///
/// Identifiant d'écran (modules_config.dart) → vraie page. L'envoi de colis
/// est l'écran principal de l'onglet ; les écrans prévus absents de cette
/// table (espace livreur) affichent un placeholder.
final ModuleRoutes deliveryRoutes = ModuleRoutes(
  moduleNumber: 4,
  screens: {'parcel': (_, _) => const ParcelPage()},
);
