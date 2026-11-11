import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_store.dart';
import '../utils/formatters.dart';

/// Démarrage commun aux deux applications (main_front.dart, main_back.dart).
Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Formatters.init();
  // Session enregistrée : l'utilisateur reste connecté entre deux lancements.
  await loadSession();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(
    ProviderScope(
      // Pas de nouvelle tentative automatique : les écrans proposent
      // « Réessayer » en cas d'erreur.
      retry: (retryCount, error) => null,
      child: app,
    ),
  );
}

/// Langue des deux applications (dates, sélecteurs, textes Material).
class AppLocalization {
  AppLocalization._();

  static const locale = Locale('fr', 'FR');
  static const supportedLocales = [
    Locale('fr', 'FR'),
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('ar', 'MA'),
  ];
  static const delegates = <LocalizationsDelegate<Object>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
