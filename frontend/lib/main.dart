import 'core/app/bootstrap.dart';
import 'front_office/front_app.dart';

/// Point d'entrée par défaut (`flutter run` sans `-t`) : le FRONT OFFICE,
/// comme `lib/main_front.dart`. Back office : `-t lib/main_back.dart`.
Future<void> main() => bootstrap(const FrontOfficeApp());
