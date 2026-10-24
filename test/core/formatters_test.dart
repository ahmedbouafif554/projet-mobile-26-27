import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/utils/formatters.dart';

import '../test_helpers.dart';

/// intl utilise des espaces insécables : on les normalise pour comparer.
String plain(String s) => s.replaceAll(RegExp('[  ]'), ' ');

void main() {
  setUpAll(setUpAppTestEnvironment);

  test('prix et nombres au format français', () {
    expect(plain(Formatters.price(12.5)), '12,50 €');
    expect(plain(Formatters.price(1240)), '1 240,00 €');
    expect(plain(Formatters.priceShort(1240.6)), '1 241 €');
    expect(plain(Formatters.count(12480)), '12 480');
    expect(Formatters.rating(4.66), '4,7');
    expect(plain(Formatters.trend(12.34)), '+12,3 %');
    expect(plain(Formatters.trend(-4.2)), '-4,2 %');
    expect(Formatters.distance(2.4), '2,4 km');
  });

  test('dates', () {
    final date = DateTime(2026, 10, 12, 14, 5);
    expect(Formatters.time(date), '14:05');
    expect(Formatters.date(date), '12 oct. 2026');
    expect(Formatters.weekday(date), 'lun.');
    final now = DateTime(2026, 10, 12, 15);
    expect(Formatters.relative(date, now: now), 'Il y a 55 min');
    expect(
      Formatters.relative(date.subtract(const Duration(days: 1)), now: now),
      'Hier',
    );
  });
}
