import 'package:flutter/services.dart';

import 'money.dart';

/// Formats an amount field while typing: accepts Persian/English digits,
/// shows Persian digits with `٬` separators. Read the raw value with
/// [normalizeAmountInput] — separators never reach the API.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final normalized = normalizeAmountInput(newValue.text);
    if (normalized == null) return oldValue; // reject non-digit input
    final formatted = formatAmountForInput(normalized);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
