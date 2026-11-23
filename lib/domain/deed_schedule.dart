import '../data/db/app_database.dart';
import 'enums.dart';

const List<String> weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

FrequencyType frequencyOf(Deed deed) =>
    FrequencyType.fromDb(deed.frequencyType);

Set<int> parseWeekdays(String? csv) {
  if (csv == null || csv.isEmpty) return {};
  return csv
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .where((day) => day >= 1 && day <= 7)
      .toSet();
}

String encodeWeekdays(Set<int> days) {
  final sorted = days.toList()..sort();
  return sorted.join(',');
}

/// Whether a deed appears on the given day's list.
bool isScheduledOn(Deed deed, DateTime day) {
  switch (frequencyOf(deed)) {
    case FrequencyType.daily:
      return true;
    case FrequencyType.weekdays:
      return parseWeekdays(deed.weekdays).contains(day.weekday);
    case FrequencyType.timesPerWeek:
    case FrequencyType.timesPerMonth:
      // Count-based goals can be done any day of the period.
      return true;
  }
}

/// Expected number of completions in [from, to] (inclusive).
int expectedOccurrences(Deed deed, DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  if (end.isBefore(start)) return 0;
  final days = end.difference(start).inDays + 1;

  switch (frequencyOf(deed)) {
    case FrequencyType.daily:
      return days;
    case FrequencyType.weekdays:
      final selected = parseWeekdays(deed.weekdays);
      if (selected.isEmpty) return 0;
      var count = 0;
      for (var day = start;
          !day.isAfter(end);
          day = day.add(const Duration(days: 1))) {
        if (selected.contains(day.weekday)) count++;
      }
      return count;
    case FrequencyType.timesPerWeek:
      final target = deed.timesPerPeriod ?? 1;
      final weeks = (days / 7).ceil();
      return weeks * target;
    case FrequencyType.timesPerMonth:
      final target = deed.timesPerPeriod ?? 1;
      final months = (end.year - start.year) * 12 + (end.month - start.month) + 1;
      return months * target;
  }
}