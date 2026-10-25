import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Formatage au format français (prix, nombres, dates) avec intl.
/// [init] doit être appelé une fois au démarrage (voir bootstrap.dart).
class Formatters {
  Formatters._();

  static const String locale = 'fr_FR';

  static Future<void> init() async {
    Intl.defaultLocale = locale;
    await initializeDateFormatting(locale);
  }

  static final _price = NumberFormat.currency(locale: locale, symbol: '€');
  static final _priceShort = NumberFormat.currency(
    locale: locale,
    symbol: '€',
    decimalDigits: 0,
  );
  static final _count = NumberFormat.decimalPattern(locale);
  static final _compact = NumberFormat.compact(locale: locale);
  static final _decimal1 = NumberFormat('0.0', locale);

  /// 12.5 → « 12,50 € »
  static String price(num value) => _price.format(value);

  /// 1240.6 → « 1 241 € » (statistiques)
  static String priceShort(num value) => _priceShort.format(value);

  /// 1240 → « 1 240 »
  static String count(num value) => _count.format(value);

  /// 12400 → « 12 k »
  static String compact(num value) => _compact.format(value);

  /// 4.66 → « 4,7 »
  static String rating(num value) => _decimal1.format(value);

  /// 12.34 → « +12,3 % »
  static String trend(num percent) =>
      '${percent >= 0 ? '+' : ''}${_decimal1.format(percent)} %';

  /// 2.4 → « 2,4 km »
  static String distance(num km) => '${_decimal1.format(km)} km';

  /// « 14:05 »
  static String time(DateTime date) => DateFormat.Hm(locale).format(date);

  /// « 12 oct. 2026 »
  static String date(DateTime date) => DateFormat.yMMMd(locale).format(date);

  /// « 12 oct. 2026 • 14:05 »
  static String dateTime(DateTime date) =>
      '${Formatters.date(date)} • ${time(date)}';

  /// « lun. » (axes des graphiques)
  static String weekday(DateTime date) => DateFormat.E(locale).format(date);

  /// « 12 oct. »
  static String dayMonth(DateTime date) => DateFormat.MMMd(locale).format(date);

  /// Durée relative courte : « À l'instant », « Il y a 5 min », « Hier »...
  static String relative(DateTime date, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return Formatters.date(date);
  }
}
