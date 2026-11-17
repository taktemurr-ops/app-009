/// All monetary values are stored as minor currency units (integer cents).
/// This is not an exchange-rate converter: a journal uses one currency.
const supportedCurrencies = <String>['TRY', 'USD', 'EUR'];

String normalizeDigits(String input) {
  final result = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      result.writeCharCode(48 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      result.writeCharCode(48 + rune - 0x06F0);
    } else if (rune >= 0xFF10 && rune <= 0xFF19) {
      result.writeCharCode(48 + rune - 0xFF10);
    } else if (rune == 0x066B) {
      result.write('.');
    } else if (rune == 0x066C || rune == 0x00A0 || rune == 0x202F) {
      result.write(',');
    } else {
      result.writeCharCode(rune);
    }
  }
  return result.toString().trim();
}

/// Positive fixed-point decimal parser. Rejects ambiguous grouping and >2
/// fractional digits instead of silently rounding personal money records.
int? parseMoney(String raw) {
  var text = normalizeDigits(raw).replaceAll(' ', '');
  if (text.isEmpty || text.length > 40 || text.startsWith('-') || text.startsWith('+')) return null;
  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  String integral;
  String fractional;
  if (lastDot >= 0 && lastComma >= 0) {
    final decimal = lastDot > lastComma ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    final split = text.split(decimal);
    if (split.length != 2 || !RegExp(r'^\d{1,3}([,.]\d{3})*$').hasMatch(split[0]) || !RegExp(r'^\d{1,2}$').hasMatch(split[1])) return null;
    integral = split[0].replaceAll(group, '');
    fractional = split[1];
  } else if (lastDot >= 0 || lastComma >= 0) {
    final separator = lastDot >= 0 ? '.' : ',';
    final split = text.split(separator);
    if (split.length != 2 || !RegExp(r'^\d+$').hasMatch(split[0]) || !RegExp(r'^\d{1,2}$').hasMatch(split[1])) return null;
    integral = split[0];
    fractional = split[1];
  } else {
    integral = text;
    fractional = '';
  }
  if (!RegExp(r'^\d{1,15}$').hasMatch(integral)) return null;
  final units = int.tryParse(integral);
  final cents = int.tryParse(fractional.padRight(2, '0'));
  if (units == null || cents == null) return null;
  final amount = units * 100 + cents;
  if (amount <= 0 || amount > 999999999999999) return null;
  return amount;
}

int sumCents(Iterable<int> cents) => cents.fold<int>(0, (a, b) => a + b);

int percentOf(int part, int whole) => whole <= 0 ? 0 : ((part * 100) / whole).round();

String monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;
