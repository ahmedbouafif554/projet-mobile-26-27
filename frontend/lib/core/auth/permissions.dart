import '../../shared/models/user.dart';

/// Les deux applications de la plateforme.
enum AppSpace {
  /// Application mobile : clients et livreurs.
  frontOffice,

  /// Panneau web « Espace Pro » : admin et restaurants.
  backOffice,
}

/// Actions protégées. Les écrans, menus et routes vérifient une permission
/// plutôt qu'un rôle : ajouter un rôle ne demande qu'une ligne ici.
enum Permission {
  // Front office
  placeOrders,
  deliverOrders,

  // Back office — Module 1
  manageUsers,
  manageRoles,
  // Module 2
  manageRestaurants,
  validateRestaurants,
  manageCategories,
  manageOwnMenu,
  // Module 3
  viewAllOrders,
  manageOwnOrders,
  refundOrders,
  // Module 4
  manageCouriers,
  manageDeliveries,
  // Module 5
  moderateReviews,
  replyToReviews,
  sendCampaigns,
  superviseChats,
  chatWithCustomers,
  // Tableau de bord
  viewGlobalDashboard,
  viewOwnStats,
}

class Permissions {
  Permissions._();

  static const Map<UserRole, Set<Permission>> _byRole = {
    UserRole.client: {Permission.placeOrders},
    UserRole.courier: {Permission.deliverOrders},
    UserRole.restaurant: {
      Permission.manageOwnMenu,
      Permission.manageOwnOrders,
      Permission.replyToReviews,
      Permission.chatWithCustomers,
      Permission.viewOwnStats,
    },
    // L'admin a accès à tout le back office.
    UserRole.admin: {
      Permission.manageUsers,
      Permission.manageRoles,
      Permission.manageRestaurants,
      Permission.validateRestaurants,
      Permission.manageCategories,
      Permission.manageOwnMenu,
      Permission.viewAllOrders,
      Permission.manageOwnOrders,
      Permission.refundOrders,
      Permission.manageCouriers,
      Permission.manageDeliveries,
      Permission.moderateReviews,
      Permission.replyToReviews,
      Permission.sendCampaigns,
      Permission.superviseChats,
      Permission.chatWithCustomers,
      Permission.viewGlobalDashboard,
      Permission.viewOwnStats,
    },
  };

  static bool can(UserRole? role, Permission permission) =>
      role != null && (_byRole[role]?.contains(permission) ?? false);

  static bool canAll(UserRole? role, Iterable<Permission> permissions) =>
      permissions.every((p) => can(role, p));

  /// Application à laquelle un rôle a accès.
  static AppSpace spaceOf(UserRole role) => switch (role) {
    UserRole.client || UserRole.courier => AppSpace.frontOffice,
    UserRole.restaurant || UserRole.admin => AppSpace.backOffice,
  };

  static bool canAccess(UserRole? role, AppSpace space) =>
      role != null && spaceOf(role) == space;
}
