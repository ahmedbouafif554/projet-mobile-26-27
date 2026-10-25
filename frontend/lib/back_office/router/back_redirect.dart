import '../../core/auth/auth_service.dart';
import '../../core/auth/permissions.dart';
import '../shell/back_nav.dart';
import 'back_routes.dart';

/// Règles d'accès du back office (redirect de go_router) :
/// - non connecté, ou compte client / livreur : page de connexion « Espace
///   Pro » uniquement ;
/// - connecté : la connexion renvoie au tableau de bord ;
/// - chaque page exige la permission de son entrée de menu (un restaurant
///   n'ouvre pas la gestion des utilisateurs…).
String? backRedirect(AuthState auth, String path) {
  final role = auth.role;
  final allowed =
      role != null && Permissions.canAccess(role, AppSpace.backOffice);
  final onLogin = path == BackRoutes.login;

  if (!allowed) return onLogin ? null : BackRoutes.login;
  if (onLogin || path == '/') return BackRoutes.dashboard;
  if (path == BackRoutes.account) return null;

  final item = navItemFor(path);
  if (item == null) return BackRoutes.dashboard;
  return item.isVisibleFor(role) ? null : BackRoutes.dashboard;
}
