import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/theme/app_theme.dart';

/// Polices larges utilisées à la place de Poppins/Inter (non disponibles
/// hors réseau). Verdana est plus large que les deux : marge de sécurité.
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

/// Prépare l'environnement de test : pas de téléchargement google_fonts,
/// et des polices réalistes (sinon flutter_test dessine des glyphes carrés
/// bien plus larges que la réalité).
Future<void> setUpAppTestEnvironment() async {
  AppTheme.useGoogleFonts = false;
  await _loadFont('Poppins');
  await _loadFont('Inter');
}

/// Hors réseau, flutter_test répond 400 à toutes les requêtes HTTP :
/// on ignore uniquement les échecs de chargement d'images Unsplash.
/// Retourne la fonction qui restaure le gestionnaire d'origine.
VoidCallback ignoreOfflineImageErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    original?.call(details);
  };
  return () => FlutterError.onError = original;
}

/// Taille d'écran logique simulée (densité 3x comme un téléphone récent).
void useScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
