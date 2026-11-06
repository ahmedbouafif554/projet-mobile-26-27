import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langues proposées dans les paramètres (l'interface est en français ;
/// les traductions arriveront avec flutter_localizations / intl).
enum AppLanguage {
  fr('Français', '🇫🇷', 'fr', 'FR'),
  en('English', '🇬🇧', 'en', 'US'),
  es('Español', '🇪🇸', 'es', 'ES'),
  ar('العربية', '🇲🇦', 'ar', 'MA');

  const AppLanguage(this.label, this.flag, this.languageCode, this.countryCode);
  final String label;
  final String flag;
  final String languageCode;
  final String countryCode;

  Locale get locale => Locale(languageCode, countryCode);

  String tr(String key) =>
      _settingsCopy[this]?[key] ?? _settingsCopy[AppLanguage.fr]![key] ?? key;
}

/// Textes de l'écran Paramètres. Le nom de chaque langue reste dans sa langue.
const _settingsCopy = <AppLanguage, Map<String, String>>{
  AppLanguage.fr: {
    'settings': 'Paramètres',
    'appearance': 'Apparence',
    'theme': 'Thème',
    'light': 'Clair',
    'dark': 'Sombre',
    'auto': 'Auto',
    'language': 'Langue',
    'security': 'Sécurité',
    'face': 'Reconnaissance faciale',
    'faceSub':
        'Rouvre votre compte client avec le visage ou l’empreinte du téléphone',
    'notifications': 'Notifications',
    'push': 'Notifications push',
    'pushSub': 'Suivi de commande, messages, offres',
    'about': 'À propos',
    'version': 'Version',
    'terms': "Conditions d'utilisation",
    'logout': 'Déconnexion',
    'noFace': 'Cet appareil ne propose pas la reconnaissance faciale.',
    'faceCancelled': 'Vérification annulée.',
  },
  AppLanguage.en: {
    'settings': 'Settings',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'light': 'Light',
    'dark': 'Dark',
    'auto': 'Auto',
    'language': 'Language',
    'security': 'Security',
    'face': 'Face recognition',
    'faceSub': 'Reopen your client account with the phone face or fingerprint',
    'notifications': 'Notifications',
    'push': 'Push notifications',
    'pushSub': 'Order tracking, messages, offers',
    'about': 'About',
    'version': 'Version',
    'terms': 'Terms of use',
    'logout': 'Log out',
    'noFace': 'This device does not offer face recognition.',
    'faceCancelled': 'Verification cancelled.',
  },
  AppLanguage.es: {
    'settings': 'Ajustes',
    'appearance': 'Apariencia',
    'theme': 'Tema',
    'light': 'Claro',
    'dark': 'Oscuro',
    'auto': 'Auto',
    'language': 'Idioma',
    'security': 'Seguridad',
    'face': 'Reconocimiento facial',
    'faceSub':
        'Vuelve a abrir tu cuenta de cliente con el rostro o la huella del teléfono',
    'notifications': 'Notificaciones',
    'push': 'Notificaciones push',
    'pushSub': 'Seguimiento del pedido, mensajes, ofertas',
    'about': 'Acerca de',
    'version': 'Versión',
    'terms': 'Condiciones de uso',
    'logout': 'Cerrar sesión',
    'noFace': 'Este dispositivo no ofrece reconocimiento facial.',
    'faceCancelled': 'Verificación cancelada.',
  },
  AppLanguage.ar: {
    'settings': 'الإعدادات',
    'appearance': 'المظهر',
    'theme': 'السمة',
    'light': 'فاتح',
    'dark': 'داكن',
    'auto': 'تلقائي',
    'language': 'اللغة',
    'security': 'الأمان',
    'face': 'التعرّف على الوجه',
    'faceSub': 'يعيد فتح حساب العميل بوجه الهاتف أو ببصمة الإصبع',
    'notifications': 'الإشعارات',
    'push': 'إشعارات الدفع',
    'pushSub': 'تتبع الطلب، الرسائل، العروض',
    'about': 'حول التطبيق',
    'version': 'الإصدار',
    'terms': 'شروط الاستخدام',
    'logout': 'تسجيل الخروج',
    'noFace': 'هذا الجهاز لا يوفّر التعرّف على الوجه.',
    'faceCancelled': 'تم إلغاء التحقق.',
  },
};

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
