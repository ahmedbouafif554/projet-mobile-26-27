import 'app_notification.dart';

/// Préférences de notifications de l'utilisateur.
class NotificationSettings {
  const NotificationSettings({
    required this.enabledTypes,
    this.inAppBanner = true,
    this.sound = true,
    this.doNotDisturb = false,
  });

  /// Activation par type de notification.
  final Map<NotificationType, bool> enabledTypes;

  /// Affiche une bannière animée en haut de l'écran à la réception.
  final bool inAppBanner;
  final bool sound;

  /// Coupe toutes les notifications.
  final bool doNotDisturb;

  static final defaults = NotificationSettings(
    enabledTypes: {
      for (final t in NotificationType.values) t: t != NotificationType.system,
    },
  );

  bool isTypeEnabled(NotificationType type) => enabledTypes[type] ?? true;

  /// Une notification de ce type doit-elle déclencher une bannière ?
  bool shouldShowBanner(NotificationType type) =>
      inAppBanner && !doNotDisturb && isTypeEnabled(type);

  NotificationSettings copyWith({
    Map<NotificationType, bool>? enabledTypes,
    bool? inAppBanner,
    bool? sound,
    bool? doNotDisturb,
  }) => NotificationSettings(
    enabledTypes: enabledTypes ?? this.enabledTypes,
    inAppBanner: inAppBanner ?? this.inAppBanner,
    sound: sound ?? this.sound,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
  );

  NotificationSettings withType(NotificationType type, bool enabled) =>
      copyWith(enabledTypes: {...enabledTypes, type: enabled});

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final types = (json['types'] as Map?)?.cast<String, dynamic>() ?? {};
    return NotificationSettings(
      enabledTypes: {
        for (final t in NotificationType.values)
          t: types[t.name] as bool? ?? true,
      },
      inAppBanner: json['in_app_banner'] as bool? ?? true,
      sound: json['sound'] as bool? ?? true,
      doNotDisturb: json['do_not_disturb'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'types': {for (final e in enabledTypes.entries) e.key.name: e.value},
    'in_app_banner': inAppBanner,
    'sound': sound,
    'do_not_disturb': doNotDisturb,
  };
}
