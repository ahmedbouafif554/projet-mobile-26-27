import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/formatters.dart';

/// Démarrage commun aux deux applications (main_front.dart, main_back.dart).
Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Formatters.init();
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
  static const supportedLocales = [locale];
  static const delegates = <LocalizationsDelegate<Object>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
