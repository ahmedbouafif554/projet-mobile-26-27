import 'back_office/back_app.dart';
import 'core/app/bootstrap.dart';
import 'core/config/app_config.dart';

/// Point d'entrée du BACK OFFICE (Espace Pro : admin et restaurants).
/// Aucune donnée fictive : restaurants, comptes, commandes et livreurs
/// viennent de l'API.
///
/// `flutter run -t lib/main_back.dart -d chrome`
Future<void> main() {
  AppConfig.useMockData = false;
  return bootstrap(const BackOfficeApp());
}
