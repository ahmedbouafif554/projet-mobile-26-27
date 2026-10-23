import 'package:flutter/material.dart';

/// Gère le mode d'affichage (clair / sombre / système).
///
/// Simple [ChangeNotifier] global : suffisant pour un frontend sans backend.
/// Dans une vraie application, on pourrait le brancher sur Provider/Riverpod
/// et persister le choix (shared_preferences).
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Suit le réglage du téléphone par défaut ; modifiable depuis le Profil.
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
