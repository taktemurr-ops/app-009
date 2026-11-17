import 'package:flutter_test/flutter_test.dart';
import 'package:butce_360/core/money.dart';

void main() {
  test('money parser supports localized decimal digits and separators', () {
    expect(parseMoney('125.95'), 12595);
    expect(parseMoney('125,95'), 12595);
    expect(parseMoney('1,234.56'), 123456);
    expect(parseMoney('1.234,56'), 123456);
    expect(parseMoney('١٢٣٫٤٥'), 12345);
    expect(parseMoney('۱۲۳٫۴۵'), 12345);
    expect(parseMoney('９９.９９'), 9999);
  });
  test('parser rejects ambiguous grouping, negative and malformed values', () {
    for (final invalid in ['-12', '+1', '0', '1.234', '1,234', '1.2.3',
      '1.1.2', 'abc', '12,3456', '12.3456', '', '1e3', 'Infinity', 'NaN']) {
      expect(parseMoney(invalid), isNull, reason: invalid);
    }
  });
  test('month key and month end are stable at leap boundaries', () {
    expect(monthKey(DateTime(2024, 2, 29)), '2024-02');
    expect(lastDayOfMonth(2024, 2), 29);
    expect(lastDayOfMonth(2026, 2), 28);
    expect(lastDayOfMonth(2026, 4), 30);
  });
  test('integer ratio never floats accounting cents', () {
    expect(sumCents([1, 2, 3]), 6);
    expect(percentOf(50, 100), 50);
    expect(percentOf(2, 0), 0);
  });
}
