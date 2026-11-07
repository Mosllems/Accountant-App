import 'package:flutter_application_1/core/format/digits.dart';
import 'package:flutter_application_1/core/format/jalali.dart';
import 'package:flutter_application_1/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('digits', () {
    test('English → Persian', () {
      expect(toPersianDigits('1405'), '۱۴۰۵');
      expect(toPersianDigits('a1b2'), 'a۱b۲');
    });

    test('Persian and Arabic-Indic → English', () {
      expect(toEnglishDigits('۱۴۰۵'), '1405');
      expect(toEnglishDigits('١٢٣'), '123');
    });

    test('search normalization unifies Arabic letters', () {
      expect(matchesSearch('علی کریمی', 'علي كريمي'), isTrue);
      expect(matchesSearch('رضا', 'علی'), isFalse);
      expect(matchesSearch('هر نامی', ''), isTrue);
    });
  });

  group('money', () {
    test('formats API strings and numbers with separators and unit', () {
      expect(formatMoney('1500000'), '۱٬۵۰۰٬۰۰۰ تومان');
      expect(formatMoney(5000000), '۵٬۰۰۰٬۰۰۰ تومان');
      expect(formatMoney('30000000'), '۳۰٬۰۰۰٬۰۰۰ تومان');
      expect(formatMoney(0), '۰ تومان');
      expect(formatMoney(999), '۹۹۹ تومان');
    });

    test('missing or invalid → dash, never zero', () {
      expect(formatMoney(null), '—');
      expect(formatMoney('abc'), '—');
    });

    test('never rounds non-integral values', () {
      expect(formatMoney('1000.5'), '۱٬۰۰۰٫۵ تومان');
    });

    test('absolute value formatting for balances', () {
      expect(formatMoneyAbs('-2000000'), '۲٬۰۰۰٬۰۰۰ تومان');
    });

    test('amount input normalization', () {
      expect(normalizeAmountInput('5000000'), '5000000');
      expect(normalizeAmountInput('۵۰۰۰۰۰۰'), '5000000');
      expect(normalizeAmountInput('۵٬۰۰۰٬۰۰۰'), '5000000');
      expect(normalizeAmountInput('5,000,000'), '5000000');
      expect(normalizeAmountInput(''), isNull);
      expect(normalizeAmountInput('12.5'), isNull);
      expect(normalizeAmountInput('-5'), isNull);
      expect(normalizeAmountInput('abc'), isNull);
    });

    test('amount validation', () {
      expect(validateAmountInput(''), isNotNull);
      expect(validateAmountInput('0'), isNotNull);
      expect(validateAmountInput('۰۰'), isNotNull);
      expect(validateAmountInput('x1'), isNotNull);
      expect(validateAmountInput('۵٬۰۰۰'), isNull);
    });

    test('chart millions labels', () {
      expect(formatMillions(300000000), '۳۰۰');
      expect(formatMillions(289900000), '۲۸۹٫۹');
      expect(formatMillions(1500000), '۱٫۵');
      expect(formatMillions(65000), '۰٫۰۷');
      expect(formatMillions(0), '۰');
    });

    test('input display formatting', () {
      expect(formatAmountForInput('5000000'), '۵٬۰۰۰٬۰۰۰');
    });
  });

  group('jalali', () {
    test('parses API dates and datetimes', () {
      final d = parseApiDate('1405-08-08')!;
      expect([d.year, d.month, d.day], [1405, 8, 8]);
      expect(parseApiDate('1405-06-17 10:20:00')!.day, 17);
      expect(parseApiDate(null), isNull);
      expect(parseApiDate('garbage'), isNull);
    });

    test('API round trip keeps Jalali format', () {
      expect(toApiDate(Jalali(1405, 8, 8)), '1405-08-08');
      expect(toApiDate(parseApiDate('1405-6-7')!), '1405-06-07');
    });

    test('display formats', () {
      expect(formatDateLong(Jalali(1405, 8, 8)), '۸ آبان ۱۴۰۵');
      expect(formatDateShort(Jalali(1405, 8, 8)), '۱۴۰۵/۰۸/۰۸');
      expect(const YearMonth(1405, 8).label, 'آبان ۱۴۰۵');
      expect(formatApiDateLong(null), '—');
    });

    test('month navigation wraps years', () {
      expect(const YearMonth(1405, 1).previous, const YearMonth(1404, 12));
      expect(const YearMonth(1404, 12).next, const YearMonth(1405, 1));
      expect(const YearMonth(1405, 8).contains(Jalali(1405, 8, 30)), isTrue);
      expect(const YearMonth(1405, 8).contains(Jalali(1405, 9, 1)), isFalse);
    });
  });
}
