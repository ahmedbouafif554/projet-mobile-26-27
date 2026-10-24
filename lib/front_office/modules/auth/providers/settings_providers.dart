import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langues proposées dans les paramètres (l'interface est en français ;
/// les traductions arriveront avec flutter_localizations / intl).
enum AppLanguage {
  fr('Français', '🇫🇷'),
  en('English', '🇬🇧'),
  es('Español', '🇪🇸'),
  ar('العربية', '🇲🇦');

  const AppLanguage(this.label, this.flag);
  final String label;
  final String flag;
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.fr;

  void set(AppLanguage language) => state = language;
}

/// Notifications push activées (réglage détaillé au module 5).
final pushEnabledProvider = NotifierProvider<PushEnabledNotifier, bool>(
  PushEnabledNotifier.new,
);

class PushEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}
