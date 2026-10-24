import 'package:flutter/material.dart';

// =============================================================================
// CONFIGURATION CENTRALE DES MODULES
//
// C'est le SEUL fichier à modifier pour ajouter, renommer ou réordonner un
// module : la barre de navigation et les routes des écrans prévus sont
// générées automatiquement à partir de [modules]. Chaque onglet s'ouvre sur
// l'écran principal de son module ([AppModule.homeScreen]).
//
// Un écran prévu affiche un placeholder tant qu'il n'est pas déclaré dans le
// fichier `lib/features/<folder>/<folder>_routes.dart` de son module.
// =============================================================================

/// Profils d'utilisateurs concernés par un écran.
enum UserRole { client, restaurant, courier, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.client => 'Client',
    UserRole.restaurant => 'Restaurant',
    UserRole.courier => 'Livreur',
    UserRole.admin => 'Admin',
  };
}

/// Écran prévu dans un module.
class PlannedScreen {
  const PlannedScreen(
    this.id,
    this.title,
    this.icon, {
    this.roles = const {},
    this.fullScreen = false,
  });

  /// Identifiant utilisé dans l'URL : `<route du module>/<id>`
  /// (l'écran principal du module est servi sur la route du module).
  final String id;
  final String title;
  final IconData icon;

  /// Utilisateurs concernés (vide = tous). Information pour l'équipe.
  final Set<UserRole> roles;

  /// `true` : l'écran s'ouvre par-dessus la barre de navigation.
  final bool fullScreen;
}

/// Description d'un module de l'application.
class AppModule {
  const AppModule({
    required this.number,
    required this.name,
    required this.label,
    required this.description,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.folder,
    required this.homeScreen,
    required this.accent,
    required this.screens,
  });

  /// Numéro du module (sert de clé stable, même si l'ordre change).
  final int number;

  /// Nom complet (info-bulle de l'onglet, placeholders).
  final String name;

  /// Label court de la barre de navigation.
  final String label;
  final String description;
  final IconData icon;
  final IconData selectedIcon;

  /// Route de base de l'onglet (ex. `/auth`).
  final String route;

  /// Dossier du module dans `lib/features/` (ex. `catalog`).
  final String folder;

  /// Écran affiché à l'ouverture de l'onglet (identifiant de [screens]).
  final String homeScreen;
  final Color accent;

  /// Écrans prévus du module.
  final List<PlannedScreen> screens;

  /// Chemin complet d'un écran : `/auth` + `login` → `/auth/login`.
  /// L'écran principal est servi sur la route du module elle-même.
  String routeOf(String screenId) =>
      screenId == homeScreen ? route : '$route/$screenId';

  /// Fichier où le module déclare ses écrans.
  String get routesFile => 'lib/features/$folder/${folder}_routes.dart';

  PlannedScreen? screen(String id) {
    for (final s in screens) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class ModulesConfig {
  ModulesConfig._();

  /// Premier écran affiché au lancement de l'application.
  static const String initialRoute = '/auth/splash';

  /// Onglet ouvert après la connexion (accueil du module Explorer).
  static const String homeRoute = '/explore';

  /// Écran de connexion (après déconnexion).
  static const String loginRoute = '/auth/login';

  /// Les modules, dans l'ordre des onglets de la barre de navigation.
  static const List<AppModule> modules = [
    AppModule(
      number: 1,
      name: 'Authentification et utilisateurs',
      label: 'Compte',
      description:
          'Inscription, connexion, profil, adresses et gestion des utilisateurs.',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      route: '/auth',
      folder: 'auth',
      homeScreen: 'profile',
      accent: Color(0xFF6366F1),
      screens: [
        PlannedScreen('splash', 'Splash', Icons.bolt_rounded, fullScreen: true),
        PlannedScreen(
          'onboarding',
          'Onboarding',
          Icons.view_carousel_rounded,
          fullScreen: true,
        ),
        PlannedScreen(
          'register',
          'Inscription',
          Icons.person_add_alt_1_rounded,
          fullScreen: true,
        ),
        PlannedScreen(
          'login',
          'Connexion',
          Icons.login_rounded,
          fullScreen: true,
        ),
        PlannedScreen(
          'otp',
          'Vérification OTP',
          Icons.pin_rounded,
          fullScreen: true,
        ),
        PlannedScreen(
          'forgot-password',
          'Mot de passe oublié',
          Icons.lock_reset_rounded,
          fullScreen: true,
        ),
        PlannedScreen('profile', 'Profil', Icons.account_circle_rounded),
        PlannedScreen(
          'edit-profile',
          'Modifier le profil',
          Icons.manage_accounts_rounded,
        ),
        PlannedScreen(
          'addresses',
          'Mes adresses',
          Icons.location_on_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen('language', 'Langue', Icons.translate_rounded),
        PlannedScreen('settings', 'Paramètres', Icons.settings_rounded),
        PlannedScreen(
          'admin-dashboard',
          'Tableau de bord admin',
          Icons.space_dashboard_rounded,
          roles: {UserRole.admin},
        ),
        PlannedScreen(
          'users',
          'Liste des utilisateurs',
          Icons.groups_rounded,
          roles: {UserRole.admin},
        ),
      ],
    ),
    AppModule(
      number: 2,
      name: 'Restaurants et catalogue',
      label: 'Explorer',
      description:
          'Accueil, restaurants, recherche, menus, produits et favoris.',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      route: '/explore',
      folder: 'catalog',
      homeScreen: 'home',
      accent: Color(0xFFFF5A1F),
      screens: [
        PlannedScreen('home', 'Accueil', Icons.home_rounded),
        PlannedScreen(
          'restaurants',
          'Liste des restaurants',
          Icons.restaurant_rounded,
        ),
        PlannedScreen('search', 'Recherche', Icons.search_rounded),
        PlannedScreen(
          'restaurant',
          'Page restaurant',
          Icons.storefront_rounded,
        ),
        PlannedScreen(
          'product',
          'Détail produit',
          Icons.fastfood_rounded,
          fullScreen: true,
        ),
        PlannedScreen(
          'favorites',
          'Favoris',
          Icons.favorite_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'menu-management',
          'Gestion du menu',
          Icons.menu_book_rounded,
          roles: {UserRole.restaurant},
        ),
        PlannedScreen(
          'restaurants-admin',
          'Gestion des restaurants',
          Icons.domain_rounded,
          roles: {UserRole.admin},
        ),
      ],
    ),
    AppModule(
      number: 3,
      name: 'Panier et commandes',
      label: 'Commandes',
      description:
          'Panier, validation, paiement, suivi et historique des commandes.',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      route: '/orders',
      folder: 'orders',
      homeScreen: 'history',
      accent: Color(0xFF16A34A),
      screens: [
        PlannedScreen(
          'cart',
          'Panier',
          Icons.shopping_bag_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'checkout',
          'Validation de commande',
          Icons.fact_check_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'payment',
          'Moyens de paiement',
          Icons.credit_card_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'confirmation',
          'Confirmation',
          Icons.check_circle_rounded,
          roles: {UserRole.client},
          fullScreen: true,
        ),
        PlannedScreen(
          'history',
          'Mes commandes',
          Icons.history_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'order-detail',
          "Détail d'une commande",
          Icons.receipt_rounded,
        ),
        PlannedScreen(
          'tracking',
          'Suivi',
          Icons.map_rounded,
          roles: {UserRole.client},
          fullScreen: true,
        ),
        PlannedScreen(
          'received-orders',
          'Commandes reçues',
          Icons.move_to_inbox_rounded,
          roles: {UserRole.restaurant},
        ),
      ],
    ),
    AppModule(
      number: 4,
      name: 'Livraison et livreurs',
      label: 'Livraison',
      description:
          'Envoi de colis, espace livreur : missions, livraison en cours et gains.',
      icon: Icons.delivery_dining_outlined,
      selectedIcon: Icons.delivery_dining_rounded,
      route: '/delivery',
      folder: 'delivery',
      homeScreen: 'parcel',
      accent: Color(0xFF0EA5E9),
      screens: [
        PlannedScreen(
          'parcel',
          'Envoi de colis',
          Icons.inventory_2_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'dashboard',
          'Dashboard livreur',
          Icons.dashboard_rounded,
          roles: {UserRole.courier},
        ),
        PlannedScreen(
          'offers',
          'Commandes à accepter',
          Icons.assignment_rounded,
          roles: {UserRole.courier},
        ),
        PlannedScreen(
          'current',
          'Livraison en cours',
          Icons.route_rounded,
          roles: {UserRole.courier},
          fullScreen: true,
        ),
        PlannedScreen(
          'earnings',
          'Gains',
          Icons.payments_rounded,
          roles: {UserRole.courier},
        ),
        PlannedScreen(
          'courier-profile',
          'Profil livreur',
          Icons.badge_rounded,
          roles: {UserRole.courier},
        ),
        PlannedScreen(
          'couriers-admin',
          'Gestion des livreurs',
          Icons.manage_accounts_rounded,
          roles: {UserRole.admin},
        ),
      ],
    ),
    AppModule(
      number: 5,
      name: 'Avis, notifications et messagerie',
      label: 'Messages',
      description: 'Avis clients, centre de notifications et conversations.',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      route: '/communication',
      folder: 'communication',
      homeScreen: 'conversations',
      accent: Color(0xFF8B5CF6),
      screens: [
        PlannedScreen(
          'notifications',
          'Notifications',
          Icons.notifications_rounded,
        ),
        PlannedScreen(
          'notification-settings',
          'Préférences de notification',
          Icons.tune_rounded,
        ),
        PlannedScreen('conversations', 'Conversations', Icons.forum_rounded),
        PlannedScreen(
          'chat',
          'Chat',
          Icons.chat_bubble_rounded,
          fullScreen: true,
        ),
        PlannedScreen('reviews', "Avis d'un restaurant", Icons.star_rounded),
        PlannedScreen(
          'my-reviews',
          'Mes avis',
          Icons.reviews_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'write-review',
          'Donner un avis',
          Icons.rate_review_rounded,
          roles: {UserRole.client},
        ),
        PlannedScreen(
          'moderation',
          'Modération des avis',
          Icons.gavel_rounded,
          roles: {UserRole.admin},
        ),
      ],
    ),
  ];

  static AppModule byNumber(int number) =>
      modules.firstWhere((m) => m.number == number);
}
