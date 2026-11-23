import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Material 3 themes for PlanIT.
/// Two styles: Midnight (blue accent) and Digital (monochrome HUD),
/// each with a dark and a light variant.
abstract final class AppTheme {
  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        border: AppColors.darkBorder,
        text: AppColors.darkText,
        muted: AppColors.darkMuted,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        border: AppColors.lightBorder,
        text: AppColors.lightText,
        muted: AppColors.lightMuted,
      );

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
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: onAccent,
      surface: surface,
      onSurface: text,
      outline: border,
      onSurfaceVariant: muted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
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
        indicatorColor: accent.withValues(alpha: 0.16),
        indicatorShape: digital
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            : null,
        height: digital ? 64 : 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 4),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius - 4),
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
}

/// Marks the active visual style so widgets can fine-tune details.
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({required this.isDigital});

  final bool isDigital;

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