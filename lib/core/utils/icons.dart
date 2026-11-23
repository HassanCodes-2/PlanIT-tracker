import 'package:material_ui/material_ui.dart';

/// Maps icon names stored in the DB to Material icons.
IconData iconForName(String? name, {IconData fallback = Icons.check_rounded}) {
  switch (name) {
    case 'fitness_center':
      return Icons.fitness_center_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'water_drop':
      return Icons.water_drop_rounded;
    case 'bedtime':
      return Icons.bedtime_rounded;
    case 'timer':
      return Icons.timer_rounded;
    case 'edit_calendar':
      return Icons.edit_calendar_rounded;
    case 'call':
      return Icons.call_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'star':
      return Icons.star_rounded;
    default:
      return fallback;
  }
}

/// Parses a `#RRGGBB` color string.
Color colorFromHex(String hex) {
  final value = hex.replaceAll('#', '');
  if (value.length != 6) return const Color(0xFF1B6CFF);
  return Color(int.parse('FF$value', radix: 16));
}