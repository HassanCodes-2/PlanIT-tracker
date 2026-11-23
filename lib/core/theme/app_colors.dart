import 'package:material_ui/material_ui.dart';

/// PlanIT design tokens, taken from the demo screenshots.
abstract final class AppColors {
  static const accent = Color(0xFF1B6CFF);

  // Dark theme (default)
  static const darkBg = Color(0xFF121214);
  static const darkSurface = Color(0xFF1E1E22);
  static const darkBorder = Color(0xFF2A2A30);
  static const darkText = Color(0xFFEDEDF0);
  static const darkMuted = Color(0xFF8E8E96);

  // Light theme
  static const lightBg = Color(0xFFF7F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE6E6EC);
  static const lightText = Color(0xFF1A1A1E);
  static const lightMuted = Color(0xFF7A7A85);

  // Outcome colors
  static const done = Color(0xFF22C55E);
  static const late = Color(0xFFF59E0B);
  static const skipped = Color(0xFFEF4444);
}