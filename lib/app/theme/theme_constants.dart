/// Theme constants for spacing, radii, and sizing.
///
/// Consolidates all design tokens in one place.
library;

/// Border radius constants aligned with Material 3.
class AppRadii {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 28;

  // Aliases for backward compatibility
  static const double xs = extraSmall;
  static const double sm = small;
  static const double md = medium;
  static const double lg = large;
  static const double xl = extraLarge;
}

/// Spacing constants for margins and paddings.
class AppSpacing {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Icon size constants.
class AppIconSizes {
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}

/// Elevation constants.
class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 4;
  static const double high = 8;
}

/// Side menu dimensions.
class AppSideMenu {
  static const double expandedWidth = 240;
  static const double collapsedWidth = 72;
  static const double mobileBreakpoint = 768;
  static const Duration animationDuration = Duration(milliseconds: 200);
}

/// Common widget dimensions.
class AppDimensions {
  // Search boxes
  static const double searchBoxWidth = 300;
  static const double searchBoxHeight = 40;

  // Button widths
  static const double buttonWidthCompact = 60;
  static const double buttonWidthMedium = 100;
  static const double buttonWidthWide = 120;

  // Table
  static const double tableHeaderHeight = 100;
  static const double tableDataRowMinHeight = 48;
  static const double tableDataRowMaxHeight = 56;
}

/// Animation durations.
class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Common opacity values.
class AppOpacity {
  static const double hover = 0.04;
  static const double subtle = 0.08;
  static const double light = 0.1;
  static const double disabled = 0.3;
  static const double medium = 0.5;
}
