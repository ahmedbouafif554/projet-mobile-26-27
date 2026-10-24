/// Fonctions de formatage (prix, dates) au format français,
/// sans dépendre du package intl.
class Formatters {
  Formatters._();

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  /// 12.5 -> « 12,50 € »
  static String price(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  /// 1240 -> « 1 240 »
  static String count(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );

  /// 4.66 -> « 4,7 »
  static String rating(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  /// 2.4 -> « 2,4 km »
  static String distance(double km) =>
      '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

  /// « 14:05 »
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// « 12 oct. 2026 »
  static String date(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// « 12 oct. 2026 • 14:05 »
  static String dateTime(DateTime date) =>
      '${Formatters.date(date)} • ${time(date)}';

  /// Durée relative courte : « À l'instant », « Il y a 5 min », « Hier »...
  static String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return Formatters.date(date);
  }
}
