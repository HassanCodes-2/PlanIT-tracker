import 'package:material_ui/material_ui.dart' show Color, IconData;

/// Phosphor Bold icons, embedded directly via assets/fonts/Phosphor-Bold.ttf.
/// Codepoints sourced from phosphor_flutter 2.1.0 (MIT license).
abstract final class Phosphor {
  static const _f = 'PhosphorBold';

  static const barbell = IconData(0xe0b6, fontFamily: _f);
  static const bookOpen = IconData(0xe0e6, fontFamily: _f);
  static const briefcase = IconData(0xe0ee, fontFamily: _f);
  static const users = IconData(0xe4d6, fontFamily: _f);
  static const drop = IconData(0xe210, fontFamily: _f);
  static const moon = IconData(0xe330, fontFamily: _f);
  static const timer = IconData(0xe492, fontFamily: _f);
  static const calendarBlank = IconData(0xe10a, fontFamily: _f);
  static const calendarCheck = IconData(0xe712, fontFamily: _f);
  static const phone = IconData(0xe3b8, fontFamily: _f);
  static const graduationCap = IconData(0xe62c, fontFamily: _f);
  static const chatCircle = IconData(0xe168, fontFamily: _f);
  static const flowerLotus = IconData(0xe6cc, fontFamily: _f);
  static const wallet = IconData(0xe68a, fontFamily: _f);
  static const gameController = IconData(0xe26e, fontFamily: _f);
  static const heart = IconData(0xe2a8, fontFamily: _f);
  static const star = IconData(0xe46a, fontFamily: _f);
  static const checkCircle = IconData(0xe184, fontFamily: _f);
  static const clock = IconData(0xe19a, fontFamily: _f);
  static const xCircle = IconData(0xe4f8, fontFamily: _f);
  static const minusCircle = IconData(0xe32c, fontFamily: _f);
  static const caretRight = IconData(0xe13a, fontFamily: _f);
  static const lightbulb = IconData(0xe2dc, fontFamily: _f);
  static const fire = IconData(0xe242, fontFamily: _f);
  static const trendUp = IconData(0xe4ae, fontFamily: _f);
  static const trendDown = IconData(0xe4ac, fontFamily: _f);
  static const notePencil = IconData(0xe34c, fontFamily: _f);
  static const arrowsClockwise = IconData(0xe094, fontFamily: _f);
  static const clockCounterClockwise = IconData(0xe1a0, fontFamily: _f);
  static const calendarDots = IconData(0xe7b4, fontFamily: _f);
  static const gear = IconData(0xe270, fontFamily: _f);
}

/// Standard icons used across the app.
abstract final class AppIcons {
  static const done = Phosphor.checkCircle;
  static const late = Phosphor.clock;
  static const skipped = Phosphor.xCircle;
  static const missed = Phosphor.minusCircle;
  static const caretRight = Phosphor.caretRight;
  static const lightbulb = Phosphor.lightbulb;
  static const fire = Phosphor.fire;
  static const trendUp = Phosphor.trendUp;
  static const trendDown = Phosphor.trendDown;
  static const notePencil = Phosphor.notePencil;
  static const star = Phosphor.star;
  static const timer = Phosphor.timer;
  static const reset = Phosphor.arrowsClockwise;
  static const history = Phosphor.clockCounterClockwise;
  static const calendar = Phosphor.calendarDots;
  static const gear = Phosphor.gear;
  static const notes = Phosphor.notePencil;
  static const stats = Phosphor.trendUp;
  static const today = Phosphor.checkCircle;
}

/// Maps icon names stored in the DB to Phosphor icons (bold weight).
/// Falls back to a Material icon when explicitly provided.
IconData iconForName(String? name, {IconData? fallback}) {
  switch (name) {
    case 'fitness_center':
      return Phosphor.barbell;
    case 'menu_book':
      return Phosphor.bookOpen;
    case 'work':
      return Phosphor.briefcase;
    case 'groups':
      return Phosphor.users;
    case 'water_drop':
      return Phosphor.drop;
    case 'bedtime':
      return Phosphor.moon;
    case 'timer':
      return Phosphor.timer;
    case 'edit_calendar':
      return Phosphor.calendarBlank;
    case 'call':
      return Phosphor.phone;
    case 'chat_bubble':
      return Phosphor.chatCircle;
    case 'self_improvement':
      return Phosphor.flowerLotus;
    case 'savings':
      return Phosphor.wallet;
    case 'sports_esports':
      return Phosphor.gameController;
    case 'school':
      return Phosphor.graduationCap;
    case 'favorite':
      return Phosphor.heart;
    case 'star':
      return Phosphor.star;
    default:
      return fallback ?? Phosphor.checkCircle;
  }
}

/// Resolves an icon for a deed: saved deed icon → inferred from the name →
/// category icon → star.
IconData iconForDeed({
  String? deedIcon,
  String? categoryIcon,
  required String name,
}) {
  if (deedIcon != null && deedIcon.isNotEmpty) {
    final icon = iconForName(deedIcon, fallback: Phosphor.star);
    if (icon != Phosphor.star || deedIcon == 'star') return icon;
  }

  final lower = name.toLowerCase();
  bool has(List<String> words) => words.any(lower.contains);

  if (has(['exercise', 'workout', 'gym', 'walk', 'run', 'pushup', 'steps', 'barbell', 'strength'])) {
    return Phosphor.barbell;
  }
  if (has(['read', 'book', 'study', 'learn', 'pages', 'language'])) {
    return Phosphor.bookOpen;
  }
  if (has(['water', 'drink', 'hydrat'])) return Phosphor.drop;
  if (has(['sleep', 'bed', 'rest', 'nap'])) return Phosphor.moon;
  if (has(['deep work', 'focus', 'work', 'project', 'office', 'write'])) {
    return Phosphor.briefcase;
  }
  if (has(['plan', 'review', 'tomorrow', 'calendar', 'journal', 'reflect'])) {
    return Phosphor.calendarCheck;
  }
  if (has(['call', 'phone', 'family'])) return Phosphor.phone;
  if (has(['message', 'text', 'friend', 'chat', 'social'])) {
    return Phosphor.chatCircle;
  }
  if (has(['meditat', 'pray', 'mindful', 'faith'])) return Phosphor.flowerLotus;
  if (has(['money', 'expense', 'save', 'budget', 'spend', 'finance'])) {
    return Phosphor.wallet;
  }
  if (has(['game', 'hobby', 'play', 'fun'])) return Phosphor.gameController;
  if (has(['love', 'heart', 'gratitude', 'kind'])) return Phosphor.heart;

  if (categoryIcon != null && categoryIcon.isNotEmpty) {
    final icon = iconForName(categoryIcon, fallback: Phosphor.star);
    if (icon != Phosphor.star || categoryIcon == 'star') return icon;
  }
  return Phosphor.star;
}

/// Parses a `#RRGGBB` color string.
Color colorFromHex(String hex) {
  final value = hex.replaceAll('#', '');
  if (value.length != 6) return const Color(0xFF1B6CFF);
  return Color(int.parse('FF$value', radix: 16));
}
