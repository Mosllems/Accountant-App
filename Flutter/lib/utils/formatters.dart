import 'package:intl/intl.dart';

/// جدا کننده هزارگان برای مبالغ ریالی/تومانی.
final NumberFormat _currencyFormat = NumberFormat.decimalPattern('fa');

/// فرمت مبلغ با جدا کننده هزارگان و پسوند تومان.
/// مثال: 1500000 → «۱٬۵۰۰٬۰۰۰ تومان»
String formatCurrency(num value) {
  return '${_currencyFormat.format(value)} تومان';
}

/// نام ماه‌های جلالی بر اساس شماره ماه (۱ تا ۱۲).
const List<String> jalaliMonths = [
  '',
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

/// تبدیل سال و ماه به متن خوانا. مثال: (۱۴۰۳، ۵) → «مرداد ۱۴۰۳»
String formatYearMonth(int year, int month) {
  final monthName = (month >= 1 && month <= 12) ? jalaliMonths[month] : '$month';
  return '$monthName $year';
}
