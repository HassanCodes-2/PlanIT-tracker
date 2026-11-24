import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Material 3 themes for PlanIT.
/// Two styles: Midnight (customizable accent) and Digital (monochrome HUD),
/// each with a dark and a light variant.
abstract final class AppTheme {
  static ThemeData get dark => darkWith(AppColors.accent);

  static ThemeData get light => lightWith(AppColors.accent);

  /// Midnight dark with a user-chosen accent, auto-corrected for contrast.
  static ThemeData darkWith(Color accent) {
    final safe =
        _accessibleAccent(accent, AppColors.darkSurface, Brightness.dark);
    return _build(
      brightness: Brightness.dark,
      bg: AppColors.darkBg,
      surface: AppColors.darkSurface,
      border: AppColors.darkBorder,
      text: AppColors.darkText,
      muted: AppColors.darkMuted,
      accent: safe,
      onAccent: _idealOn(safe),
    );
  }

  /// Midnight light with a user-chosen accent, auto-corrected for contrast.
  static ThemeData lightWith(Color accent) {
    final safe =
        _accessibleAccent(accent, AppColors.lightSurface, Brightness.light);
    return _build(
      brightness: Brightness.light,
      bg: AppColors.lightBg,
      surface: AppColors.lightSurface,
      border: AppColors.lightBorder,
      text: AppColors.lightText,
      muted: AppColors.lightMuted,
      accent: safe,
      onAccent: _idealOn(safe),
    );
  }

  static ThemeData get digitalDark => _build(
        brightness: Brightness.dark,
        bg: AppColors.digitalDarkBg,
        surface: AppColors.digitalDarkSurface,
        border: AppColors.digitalDarkBorder,
        text: AppColors.digitalDarkText,
        muted: AppColors.digitalDarkMuted,
        accent: Colors.white,
        onAccent: Colors.black,
        cardRadius: 10,
        radius: 12,
        digital: true,
      );

  static ThemeData get digitalLight => _build(
        brightness: Brightness.light,
        bg: AppColors.digitalLightBg,
        surface: AppColors.digitalLightSurface,
        border: AppColors.digitalLightBorder,
        text: AppColors.digitalLightText,
        muted: AppColors.digitalLightMuted,
        accent: Colors.black,
        onAccent: Colors.white,
        cardRadius: 10,
        radius: 12,
        digital: true,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color border,
    required Color text,
    required Color muted,
    Color accent = AppColors.accent,
    Color onAccent = Colors.white,
    double cardRadius = 16,
    double radius = 16,
    bool digital = false,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final fieldBorder = digital
        ? (brightness == Brightness.dark
            ? const Color(0xFF5F5F6A)
            : const Color(0xFF85858F))
        : (brightness == Brightness.dark
            ? const Color(0xFF75757F)
            : const Color(0xFF8A8A93));
    final accentText =
        _accessibleAccent(accent, bg, brightness, ratio: 4.5);
    final snackBg = brightness == Brightness.dark
        ? const Color(0xFF2E2E36)
        : const Color(0xFF202024);
    final snackAction =
        _accessibleAccent(accent, snackBg, Brightness.dark, ratio: 4.5);
    final scheme = baseScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accentText,
      onSecondary: onAccent,
      surface: surface,
      onSurface: text,
      outline: fieldBorder,
      outlineVariant: border,
      onSurfaceVariant: muted,
      error: digital ? muted : baseScheme.error,
      onError: digital ? surface : baseScheme.onError,
    );

    final textTheme = _textTheme(text, muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      extensions: [AppStyle(isDigital: digital)],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent,
        indicatorShape: digital
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            : null,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? onAccent : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? onAccent : muted,
          ),
        ),
        height: digital ? 64 : 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.16),
        side: BorderSide(color: fieldBorder),
        labelStyle: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        checkmarkColor: accentText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerBackgroundColor: accent,
        headerForegroundColor: onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.dialog),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.dialog),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.dialog),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? accent
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? onAccent : text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: fieldBorder)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: snackAction,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius - 4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentText,
          side: BorderSide(color: fieldBorder),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: digital ? 0 : null,
        shape: digital
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
            : null,
      ),
    );
  }

  /// Material 3 type scale tuned for a calm productivity app.
  static TextTheme _textTheme(Color text, Color muted) => TextTheme(
        displaySmall: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: text),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, color: text),
        titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: text),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: text),
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, height: 1.25, color: text),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: text),
        bodyLarge:
            TextStyle(fontSize: 15, height: 1.4, color: text),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.4, color: text),
        bodySmall:
            TextStyle(fontSize: 12, height: 1.35, color: muted),
        labelLarge: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: text),
        labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: muted),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            color: muted),
      );

  static double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Nudges the accent toward white/black until it reaches WCAG 3:1
  /// (UI-component contrast) against the given surface, so custom accents
  /// stay visible while keeping buttons and icons legible.
  static Color _accessibleAccent(
    Color accent,
    Color against,
    Brightness brightness, {
    double ratio = 3.0,
  }) {
    if (_contrastRatio(accent, against) >= ratio) return accent;
    final target = brightness == Brightness.dark ? Colors.white : Colors.black;
    for (var t = 0.05; t <= 0.95; t += 0.05) {
      final candidate = Color.lerp(accent, target, t)!;
      if (_contrastRatio(candidate, against) >= ratio) return candidate;
    }
    return target;
  }

  /// Picks black or white text for the best contrast on the accent fill.
  /// Prefers white for saturated fills (MD3 tonal pairing), black for
  /// luminous fills like amber or lime.
  static Color _idealOn(Color fill) {
    final white = _contrastRatio(Colors.white, fill);
    final black = _contrastRatio(Colors.black, fill);
    if (white >= 4.5) return Colors.white;
    if (black >= 4.5) return Colors.black;
    return white >= black ? Colors.white : Colors.black;
  }

  /// Public helper for widgets that render colored chips/dots: darken or
  /// lighten the color until it is at least [ratio] readable on [against].
  static Color ensureVisible(
    Color color,
    Color against,
    Brightness brightness, {
    double ratio = 3.0,
  }) {
    return _accessibleAccent(color, against, brightness, ratio: ratio);
  }

  /// Best black/white foreground for an arbitrary fill color.
  static Color onColor(Color fill) => _idealOn(fill);
}

/// Marks the active visual style so widgets can fine-tune details.
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({required this.isDigital});

  final bool isDigital;

  /// Card corner radius for the active style (Digital is tighter).
  double get cardRadius => isDigital ? 10 : 16;

  @override
  AppStyle copyWith({bool? isDigital}) =>
      AppStyle(isDigital: isDigital ?? this.isDigital);

  @override
  AppStyle lerp(ThemeExtension<AppStyle>? other, double t) => this;
}

extension AppStyleContext on BuildContext {
  AppStyle get appStyle =>
      Theme.of(this).extension<AppStyle>() ??
      const AppStyle(isDigital: false);
}