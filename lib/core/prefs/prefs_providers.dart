import 'package:material_ui/material_ui.dart' show Color, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Visual styles offered by the app.
enum AppThemeStyle {
  midnight('midnight'),
  digital('digital');

  const AppThemeStyle(this.prefValue);

  final String prefValue;

  static AppThemeStyle fromPrefs(String? value) => values.firstWhere(
        (style) => style.prefValue == value,
        orElse: () => AppThemeStyle.midnight,
      );
}

/// The accent used by the Midnight style. Persisted as #RRGGBB.
class AccentColorNotifier extends Notifier<Color> {
  static const _key = 'accent_color';

  @override
  Color build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    if (stored == null || stored.length != 7 || !stored.startsWith('#')) {
      return AppColors.accent;
    }
    final value = int.tryParse(stored.substring(1), radix: 16);
    if (value == null) return AppColors.accent;
    return Color(0xFF000000 | value);
  }

  Future<void> setColor(Color color) async {
    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
    await ref.read(sharedPreferencesProvider).setString(_key, hex);
    state = color;
  }
}

final accentColorProvider =
    NotifierProvider<AccentColorNotifier, Color>(AccentColorNotifier.new);

class ThemeStyleNotifier extends Notifier<AppThemeStyle> {
  static const _key = 'theme_style';

  @override
  AppThemeStyle build() => AppThemeStyle.fromPrefs(
        ref.watch(sharedPreferencesProvider).getString(_key),
      );

  Future<void> setStyle(AppThemeStyle style) async {
    await ref.read(sharedPreferencesProvider).setString(_key, style.prefValue);
    state = style;
  }
}

final themeStyleProvider =
    NotifierProvider<ThemeStyleNotifier, AppThemeStyle>(
  ThemeStyleNotifier.new,
);

/// Whether the welcome/onboarding flow has been completed.
class OnboardedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool('onboarding_done') ?? false;

  Future<void> complete() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('onboarding_done', true);
    state = true;
  }

  /// Re-opens setup without deleting any existing deeds or notes.
  Future<void> reset() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('onboarding_done', false);
    state = false;
  }
}

final onboardedProvider =
    NotifierProvider<OnboardedNotifier, bool>(OnboardedNotifier.new);

/// The name the user chose during onboarding (used for greetings).
class UserNameNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString('user_name') ?? '';

  Future<void> set(String name) async {
    await ref.read(sharedPreferencesProvider).setString('user_name', name);
    state = name;
  }
}

final userNameProvider =
    NotifierProvider<UserNameNotifier, String>(UserNameNotifier.new);