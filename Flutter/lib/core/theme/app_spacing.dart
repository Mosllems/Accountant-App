/// Spacing scale and corner radii. Avoid arbitrary values in screens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Internal card padding.
  static const double cardPadding = lg;

  /// Gap between cards.
  static const double cardGap = md;

  /// Gap between major sections.
  static const double sectionGap = xl;

  /// Horizontal page gutter.
  static const double page = lg;

  /// Max readable content width on wide screens.
  static const double maxContentWidth = 960;

  /// Minimum touch target.
  static const double minTouch = 48;
}

abstract final class AppRadii {
  static const double card = 14;
  static const double button = 12;
  static const double field = 12;
  static const double chip = 10;
  static const double dialog = 18;
  static const double badge = 8;
}
