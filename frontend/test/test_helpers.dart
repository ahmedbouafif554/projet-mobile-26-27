import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/app_config.dart';
import 'package:superfaster/core/theme/app_theme.dart';
import 'package:superfaster/core/utils/formatters.dart';

/// Polices larges utilisées à la place de Poppins/Inter (hors réseau) :
/// Verdana est plus large que les deux, ce qui donne une marge de sécurité.
const _wideFonts = [
  'C:/Windows/Fonts/verdana.ttf',
  '/System/Library/Fonts/Supplemental/Verdana.ttf',
  '/usr/share/fonts/truetype/msttcorefonts/Verdana.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
];

Future<void> _loadFont(String family) async {
  for (final path in _wideFonts) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = ByteData.sublistView(file.readAsBytesSync());
    await (FontLoader(family)..addFont(Future.value(bytes))).load();
    return;
  }
}

/// Pas de google_fonts ni de délai réseau simulé dans les tests.
Future<void> setUpAppTestEnvironment() async {
  AppTheme.useGoogleFonts = false;
  AppConfig.useApiAuth = false;
  AppConfig.mockLatencyMin = Duration.zero;
  AppConfig.mockLatencyMax = Duration.zero;
  await Formatters.init();
  await _loadFont('Poppins');
  await _loadFont('Inter');
}

/// Hors réseau, les photos ne se chargent pas : on ignore ces erreurs-là.
VoidCallback ignoreOfflineImageErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    original?.call(details);
  };
  return () => FlutterError.onError = original;
}

/// Taille d'écran logique simulée.
void useScreenSize(WidgetTester tester, Size size, {double ratio = 2}) {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

/// Fait avancer le temps image par image (animations enchaînées).
Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
  for (var t = 0; t <= ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
