/// Money parsing / formatting / input normalization.
///
/// The API sends money as integer decimal strings (e.g. `"30000000"`,
/// `decimal_places=0`). Values are never rounded or altered here.
library;

import 'digits.dart';

/// Persian thousands separator.
const String thousandsSeparator = '٬';

/// Unit label.
const String currencyUnit = 'تومان';

/// Placeholder shown when a value is missing or invalid (never `0`).
const String missingValue = '—';

/// Parses an API money value (`String` or `num`). Returns null if invalid.
num? parseMoney(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  final text = toEnglishDigits(value.toString().trim());
  if (text.isEmpty) return null;
  return num.tryParse(text);
}

/// Groups an integer string with Persian separators: `1500000` → `۱٬۵۰۰٬۰۰۰`.
String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(thousandsSeparator);
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats a number with Persian digits and separators (no unit).
///
/// Integral values print without decimals. Non-integral values keep their
/// fraction exactly as given (never rounded).
String formatNumber(num value) {
  final negative = value < 0;
  final abs = value.abs();
  final raw = abs == abs.truncate()
      ? abs.truncate().toString()
      : abs.toString();
  final parts = raw.split('.');
  var result = _groupDigits(parts.first);
  if (parts.length > 1) result = '$result٫${parts[1]}';
  result = toPersianDigits(result);
  // Unicode minus with LTR mark keeps the sign attached in RTL text.
  return negative ? '‎−$result' : result;
}

/// `1500000` → `۱٬۵۰۰٬۰۰۰ تومان`; null/invalid → `—`.
String formatMoney(Object? value, {bool withUnit = true}) {
  final parsed = value is num ? value : parseMoney(value);
  if (parsed == null) return missingValue;
  final number = formatNumber(parsed);
  return withUnit ? '$number $currencyUnit' : number;
}

/// Like [formatMoney] but shows the absolute value. Used for balances where
/// the direction is communicated by the backend status badge next to it.
String formatMoneyAbs(Object? value, {bool withUnit = true}) {
  final parsed = value is num ? value : parseMoney(value);
  if (parsed == null) return missingValue;
  return formatMoney(parsed.abs(), withUnit: withUnit);
}

/// Compact value in millions for chart axes: `30000000` → `۳۰`,
/// `1500000` → `۱٫۵`. The axis must state «میلیون تومان».
///
/// Chart labels only (the exact amount is shown separately): values under
/// 10 million keep 2 decimals, larger ones 1; trailing zeros are dropped.
String formatMillions(num value) {
  final m = value / 1000000;
  var text = m == m.truncate()
      ? m.truncate().toString()
      : m.toStringAsFixed(m.abs() < 10 ? 2 : 1);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return toPersianDigits(text.replaceAll('.', '٫'));
}

/// Normalizes a user-typed amount to ASCII digits only.
///
/// Accepts Persian/Arabic/English digits and separators (`٬` `,` `،` spaces).
/// Returns null if anything else is present (letters, decimals, signs).
String? normalizeAmountInput(String input) {
  var text = toEnglishDigits(input.trim());
  text = text.replaceAll(RegExp(r'[٬,،\s٬]'), '');
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  // Strip leading zeros but keep a single 0.
  text = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return text;
}

/// Validates an amount field. Returns a Persian error or null when valid.
String? validateAmountInput(String? input) {
  if (input == null || input.trim().isEmpty) return 'مبلغ را وارد کنید.';
  final normalized = normalizeAmountInput(input);
  if (normalized == null) return 'مبلغ فقط باید شامل عدد باشد.';
  if (BigInt.parse(normalized) <= BigInt.zero) {
    return 'مبلغ باید بیشتر از صفر باشد.';
  }
  return null;
}

/// Formats ASCII digits for display while typing: `5000000` → `۵٬۰۰۰٬۰۰۰`.
String formatAmountForInput(String asciiDigits) =>
    toPersianDigits(_groupDigits(asciiDigits));
