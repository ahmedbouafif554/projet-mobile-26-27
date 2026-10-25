import '../../core/auth/auth_service.dart';
import '../../core/auth/permissions.dart';
import '../../shared/models/user.dart';
import 'front_routes.dart';

/// Règles d'accès du front office (redirect de go_router), sans effet de
/// bord pour être testées facilement :
/// - non connecté : seules les pages publiques (connexion, inscription…) ;
/// - connecté : les pages publiques renvoient vers l'accueil du rôle ;
/// - un client n'ouvre pas l'espace livreur, un livreur n'ouvre que son
///   espace et les pages du compte ;
/// - les comptes du back office (restaurant, admin) n'ont pas accès à l'app.
String? frontRedirect(AuthState auth, String path) {
  // Le splash décide lui-même où aller.
  if (path == FrontRoutes.splash) return null;

  final isPublic = FrontRoutes.publicPaths.contains(path);
  final role = auth.role;
  if (role == null || !Permissions.canAccess(role, AppSpace.frontOffice)) {
    return isPublic ? null : FrontRoutes.login;
  }
  if (isPublic) return FrontRoutes.homeFor(role);

  bool under(String area) => path == area || path.startsWith('$area/');
  final courierSpace = under(FrontRoutes.courierArea);
  final account = under(FrontRoutes.accountArea);

  if (role == UserRole.courier && !courierSpace && !account) {
    return FrontRoutes.courierDashboard;
  }
  if (role == UserRole.client && courierSpace) return FrontRoutes.explore;
  return null;
}
