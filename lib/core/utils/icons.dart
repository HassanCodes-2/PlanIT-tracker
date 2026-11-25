import 'package:material_ui/material_ui.dart' show Color, IconData;

import '../../domain/enums.dart';

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
  static const checkSquare = IconData(0xe186, fontFamily: _f);
  static const clock = IconData(0xe19a, fontFamily: _f);
  static const check = IconData(0xe182, fontFamily: _f);
  static const circle = IconData(0xe18a, fontFamily: _f);
  static const play = IconData(0xe3d0, fontFamily: _f);
  static const arrowLeft = IconData(0xe058, fontFamily: _f);
  static const arrowRight = IconData(0xe06c, fontFamily: _f);
  static const plus = IconData(0xe3d4, fontFamily: _f);
  static const x = IconData(0xe4f6, fontFamily: _f);
  static const magnifyingGlass = IconData(0xe30c, fontFamily: _f);
  static const trash = IconData(0xe4a6, fontFamily: _f);
  static const pencilSimple = IconData(0xe3b4, fontFamily: _f);
  static const shareNetwork = IconData(0xe408, fontFamily: _f);
  static const arrowCounterClockwise = IconData(0xe038, fontFamily: _f);
  static const bell = IconData(0xe0ce, fontFamily: _f);
  static const rocketLaunch = IconData(0xe3fe, fontFamily: _f);
  static const user = IconData(0xe4c2, fontFamily: _f);
  static const database = IconData(0xe1de, fontFamily: _f);
  static const squaresFour = IconData(0xe464, fontFamily: _f);
  static const pushPin = IconData(0xe3e2, fontFamily: _f);
  static const pushPinSlash = IconData(0xe3e4, fontFamily: _f);
  static const confetti = IconData(0xe81a, fontFamily: _f);
  static const pause = IconData(0xe39e, fontFamily: _f);
  static const dotsThree = IconData(0xe1fe, fontFamily: _f);
  static const arrowClockwise = IconData(0xe036, fontFamily: _f);
  static const archive = IconData(0xe00c, fontFamily: _f);
  static const tag = IconData(0xe478, fontFamily: _f);
  static const xCircle = IconData(0xe4f8, fontFamily: _f);
  static const xSquare = IconData(0xe4fa, fontFamily: _f);
  static const minusCircle = IconData(0xe32c, fontFamily: _f);
  static const minusSquare = IconData(0xed4c, fontFamily: _f);
  static const square = IconData(0xe45e, fontFamily: _f);
  static const caretRight = IconData(0xe13a, fontFamily: _f);
  static const caretDown = IconData(0xe136, fontFamily: _f);
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
  static const doneSquare = Phosphor.checkSquare;
  static const late = Phosphor.clock;
  static const skipped = Phosphor.xCircle;
  static const skippedSquare = Phosphor.xSquare;
  static const missed = Phosphor.minusCircle;
  static const missedSquare = Phosphor.minusSquare;
  static const uncheckedSquare = Phosphor.square;
  static const caretRight = Phosphor.caretRight;
  static const caretDown = Phosphor.caretDown;
  static const lightbulb = Phosphor.lightbulb;
  static const fire = Phosphor.fire;
  static const trendUp = Phosphor.trendUp;
  static const trendDown = Phosphor.trendDown;
  static const notePencil = Phosphor.notePencil;
  static const star = Phosphor.star;
  static const timer = Phosphor.timer;
  static const focus = Phosphor.play;
  static const back = Phosphor.arrowLeft;
  static const forward = Phosphor.arrowRight;
  static const add = Phosphor.plus;
  static const close = Phosphor.x;
  static const search = Phosphor.magnifyingGlass;
  static const delete = Phosphor.trash;
  static const edit = Phosphor.pencilSimple;
  static const share = Phosphor.shareNetwork;
  static const restore = Phosphor.arrowCounterClockwise;
  static const bell = Phosphor.bell;
  static const rocket = Phosphor.rocketLaunch;
  static const person = Phosphor.user;
  static const storage = Phosphor.database;
  static const apps = Phosphor.squaresFour;
  static const pin = Phosphor.pushPin;
  static const pinOff = Phosphor.pushPinSlash;
  static const confetti = Phosphor.confetti;
  static const pause = Phosphor.pause;
  static const more = Phosphor.dotsThree;
  static const refresh = Phosphor.arrowClockwise;
  static const empty = Phosphor.square;
  static const tag = Phosphor.tag;
  static const check = Phosphor.check;
  static const circle = Phosphor.circle;
  static const reset = Phosphor.arrowsClockwise;
  static const history = Phosphor.clockCounterClockwise;
  static const archive = Phosphor.archive;
  static const calendar = Phosphor.calendarDots;
  static const gear = Phosphor.gear;
  static const notes = Phosphor.notePencil;
  static const stats = Phosphor.trendUp;
  static const today = Phosphor.calendarCheck;
}

/// Digital uses square checks for direct states; Midnight uses circles.
/// Late remains a clock because the time cue matters more than geometry.
IconData statusIcon(LogStatus status, {required bool digital}) =>
    switch (status) {
      LogStatus.done => digital ? AppIcons.doneSquare : AppIcons.done,
      LogStatus.late => AppIcons.late,
      LogStatus.skipped =>
        digital ? AppIcons.skippedSquare : AppIcons.skipped,
    };

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
