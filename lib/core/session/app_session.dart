import 'package:flutter/foundation.dart';

/// Session simulée : l'utilisateur est-il connecté ?
/// À remplacer par la vraie authentification (Module 1).
class AppSession extends ChangeNotifier {
  AppSession._();
  static final AppSession instance = AppSession._();

  bool _loggedIn = false;

  bool get isLoggedIn => _loggedIn;

  void login() {
    _loggedIn = true;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    notifyListeners();
  }
}
