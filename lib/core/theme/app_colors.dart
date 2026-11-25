import 'package:material_ui/material_ui.dart';

import '../../domain/enums.dart';

/// PlanIT design tokens, taken from the demo screenshots.
abstract final class AppColors {
  static const accent = Color(0xFF1B6CFF);

  // Dark theme (default)
  static const darkBg = Color(0xFF121214);
  static const darkSurface = Color(0xFF1E1E22);
  static const darkBorder = Color(0xFF2A2A30);
  static const darkText = Color(0xFFEDEDF0);
  static const darkMuted = Color(0xFF9A9AA5);

  // Light theme
  static const lightBg = Color(0xFFF7F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE6E6EC);
  static const lightText = Color(0xFF1A1A1E);
  static const lightMuted = Color(0xFF6B6B75);

  // Outcome colors (accessible variants for light surfaces)
  static const done = Color(0xFF22C55E);
  static const late = Color(0xFFF59E0B);
  static const skipped = Color(0xFFEF4444);
  static const doneLight = Color(0xFF15803D);
  static const lateLight = Color(0xFFB45309);
  static const skippedLight = Color(0xFFB91C1C);

  // Digital theme — monochrome HUD
  static const digitalDarkBg = Color(0xFF000000);
  static const digitalDarkSurface = Color(0xFF0A0A0C);
  static const digitalDarkBorder = Color(0xFF1F1F24);
  static const digitalDarkText = Color(0xFFF6F6F8);
  static const digitalDarkMuted = Color(0xFF8A8A92);

  static const digitalLightBg = Color(0xFFF6F6F7);
  static const digitalLightSurface = Color(0xFFFFFFFF);
  static const digitalLightBorder = Color(0xFFE1E1E5);
  static const digitalLightText = Color(0xFF0A0A0B);
  static const digitalLightMuted = Color(0xFF6E6E76);

  /// One status palette shared by Today, Stats and deed history so a state
  /// never changes meaning (or contrast) between screens.
  static Color outcome(
    LogStatus status,
    ThemeData theme, {
    required bool digital,
  }) {
    final scheme = theme.colorScheme;
    if (digital) {
      // Full-opacity grayscale ramp: each step stays above 3:1 on the HUD
      // surface, while the glyph carries the meaning for color-blind users.
      return switch (status) {
        LogStatus.done => scheme.onSurface,
        LogStatus.late => Color.lerp(scheme.onSurface, scheme.surface, 0.2)!,
        LogStatus.skipped => scheme.onSurfaceVariant,
      };
    }
    final isLight = theme.brightness == Brightness.light;
    return switch (status) {
      LogStatus.done => isLight ? doneLight : done,
      LogStatus.late => isLight ? lateLight : late,
      LogStatus.skipped => isLight ? skippedLight : skipped,
    };
  }

  /// Unlogged scheduled days are neutral, never a low-contrast outline-only
  /// cell. The missed glyph provides the non-color cue.
  static Color missed(ThemeData theme, {required bool digital}) {
    if (digital) {
      return theme.brightness == Brightness.dark
          ? const Color(0xFF6E6E78)
          : const Color(0xFF8A8A93);
    }
    return theme.colorScheme.onSurfaceVariant;
  }
}