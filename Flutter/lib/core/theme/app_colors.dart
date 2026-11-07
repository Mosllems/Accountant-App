import 'package:flutter/material.dart';

/// All app colors. Screens must use these tokens, never inline hex values.
///
/// Brand palette (blue, chosen by the owner on 2026-11-07):
///   #021024  #052659  #5483B3  #7DA0CA  #C1E8FF
///
/// Light mode only for now. To add dark mode later, create a second palette
/// with the same names and select it in `AppTheme`.
abstract final class AppColors {
  // ---------------------------------------------------------------- palette
  static const Color blue900 = Color(0xFF021024);
  static const Color blue700 = Color(0xFF052659);
  static const Color blue500 = Color(0xFF5483B3);
  static const Color blue300 = Color(0xFF7DA0CA);
  static const Color blue100 = Color(0xFFC1E8FF);

  // ------------------------------------------------------------- semantics

  /// Darkest brand color: key financial cards, headings, important text.
  static const Color navy = blue900;

  /// Primary actions, active navigation, selected controls.
  /// One step lighter than [navy] so buttons never look like dark cards.
  static const Color accent = blue700;

  /// Soft highlight: nav indicator, avatars, selected backgrounds.
  static const Color accentSoft = Color(0xFFE3F3FF); // tint of blue100

  /// Decorative icons (not for small text — contrast too low on white).
  static const Color iconAccent = blue500;

  static const Color background = Color(0xFFF5F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF2F8);
  static const Color border = Color(0xFFDDE5EF);

  static const Color textPrimary = navy;
  static const Color textSecondary = Color(0xFF4B5B76);
  static const Color textMuted = Color(0xFF7F8EA6);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkMuted = blue300;

  static const Color disabledBg = Color(0xFFE4E9F0);
  static const Color disabledText = Color(0xFF97A3B6);

  static const Color error = Color(0xFFC62828);
  static const Color errorSoft = Color(0xFFFDECEC);
  static const Color success = Color(0xFF1E7A46);
  static const Color info = blue700;

  // Account status — unchanged on purpose (red / yellow / green stand out
  // well against the blue palette). Always shown with a text label.
  static const Color debtorBg = Color(0xFFFDE8E8);
  static const Color debtorText = Color(0xFFB42318);
  static const Color creditorBg = Color(0xFFFEF4D6);
  static const Color creditorText = Color(0xFF8A5A00);
  static const Color paidBg = Color(0xFFE3F6EA);
  static const Color paidText = Color(0xFF1E7A46);

  // Chart series: dark vs light blue stay distinguishable.
  static const Color chartPrimary = blue700;
  static const Color chartSecondary = blue300;
  static const Color chartGrid = Color(0xFFE6EDF5);
}
