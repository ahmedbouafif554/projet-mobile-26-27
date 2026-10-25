import 'back_office/back_app.dart';
import 'core/app/bootstrap.dart';

/// Point d'entrée du BACK OFFICE (panneau web « Espace Pro » : admin et
/// restaurants).
///
/// `flutter run -t lib/main_back.dart -d chrome`
Future<void> main() => bootstrap(const BackOfficeApp());
