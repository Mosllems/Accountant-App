/// Persian / English digit conversion. The only place digits are converted.
library;

const _persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts ASCII digits to Persian digits: `1405` → `۱۴۰۵`.
String toPersianDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.write(_persian[rune - 0x30]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Converts Persian (۰-۹) and Arabic-Indic (٠-٩) digits to ASCII digits.
String toEnglishDigits(String input) {
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(_persian[i], '$i').replaceAll(_arabic[i], '$i');
  }
  return out;
}

/// Normalizes text for search: Arabic ي/ك → Persian ی/ک, removes ZWNJ,
/// unifies digits and case, trims.
String normalizeForSearch(String input) =>
    toEnglishDigits(input)
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('‌', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

/// True if [text] contains [query] after [normalizeForSearch].
bool matchesSearch(String text, String query) =>
    query.isEmpty ||
    normalizeForSearch(text).contains(normalizeForSearch(query));

/// Formats a count with Persian digits: `12` → `۱۲`.
String formatCount(int value) => toPersianDigits(value.toString());
