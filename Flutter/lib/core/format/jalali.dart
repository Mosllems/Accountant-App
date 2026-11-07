/// Jalali (Persian calendar) helpers. The API already uses Jalali
/// `YYYY-MM-DD` strings, so no Gregorian conversion happens at the boundary.
library;

import 'package:shamsi_date/shamsi_date.dart';

import 'digits.dart';

export 'package:shamsi_date/shamsi_date.dart' show Jalali;

const List<String> jalaliMonthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// Week day initials, Saturday first (shamsi_date `weekDay` 1 = Saturday).
const List<String> jalaliWeekDayInitials = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

String monthName(int month) =>
    (month >= 1 && month <= 12) ? jalaliMonthNames[month - 1] : '$month';

/// Parses an API date (`1405-06-17`, or a datetime starting with it).
/// Returns null for missing or invalid values.
Jalali? parseApiDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})')
      .firstMatch(toEnglishDigits(value.trim()));
  if (match == null) return null;
  try {
    return Jalali(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  } on Object {
    return null;
  }
}

/// Serializes a date for the API: `1405-08-08`.
String toApiDate(Jalali date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// `۸ آبان ۱۴۰۵`
String formatDateLong(Jalali date) =>
    toPersianDigits('${date.day} ${monthName(date.month)} ${date.year}');

/// `۱۴۰۵/۰۸/۰۸`
String formatDateShort(Jalali date) => toPersianDigits(
  '${date.year}/${date.month.toString().padLeft(2, '0')}/'
  '${date.day.toString().padLeft(2, '0')}',
);

/// Formats an API date string, `—` when missing/invalid.
String formatApiDateLong(String? value) {
  final date = parseApiDate(value);
  return date == null ? '—' : formatDateLong(date);
}

/// A Jalali year + month (the unit of MonthlySalary / MonthlyAccount).
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  factory YearMonth.of(Jalali date) => YearMonth(date.year, date.month);

  factory YearMonth.current() => YearMonth.of(Jalali.now());

  final int year;
  final int month;

  YearMonth get previous =>
      month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  YearMonth get next =>
      month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  bool contains(Jalali? date) =>
      date != null && date.year == year && date.month == month;

  /// `آبان ۱۴۰۵`
  String get label => toPersianDigits('${monthName(month)} $year');

  @override
  int compareTo(YearMonth other) => year != other.year
      ? year.compareTo(other.year)
      : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-$month';
}
