import 'core/app/bootstrap.dart';
import 'front_office/front_app.dart';

/// Point d'entrée du FRONT OFFICE (application mobile clients et livreurs).
///
/// `flutter run -t lib/main_front.dart`
Future<void> main() => bootstrap(const FrontOfficeApp());
