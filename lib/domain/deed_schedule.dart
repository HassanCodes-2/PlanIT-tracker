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

/// The week/month window a count-based goal is measured over.
({DateTime start, DateTime end})? goalPeriod(Deed deed, DateTime day) {
  final frequency = frequencyOf(deed);
  if (!frequency.isCountBased) return null;
  final selected = dateOnly(day);
  if (frequency == FrequencyType.timesPerWeek) {
    final start =
        selected.subtract(Duration(days: selected.weekday - 1));
    return (start: start, end: start.add(const Duration(days: 6)));
  }
  final start = DateTime(selected.year, selected.month, 1);
  final end =
      DateTime(selected.year, selected.month + 1, 1).subtract(const Duration(days: 1));
  return (start: start, end: end);
}

/// Completed days (done or late) inside the goal's active period.
int goalDoneCount(Deed deed, Iterable<DeedLog> logs, DateTime day) {
  final period = goalPeriod(deed, day);
  if (period == null) return 0;
  return logs
      .where((log) =>
          log.deedId == deed.id &&
          (LogStatus.fromDb(log.status) == LogStatus.done ||
              LogStatus.fromDb(log.status) == LogStatus.late) &&
          !dateOnly(log.day).isBefore(period.start) &&
          !dateOnly(log.day).isAfter(period.end))
      .length;
}

bool goalIsMet(Deed deed, Iterable<DeedLog> logs, DateTime day) {
  if (!frequencyOf(deed).isCountBased) return false;
  return goalDoneCount(deed, logs, day) >= (deed.timesPerPeriod ?? 1);
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