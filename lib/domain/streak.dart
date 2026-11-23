import 'enums.dart';

/// Consecutive days with at least one log, ending today
/// (or yesterday, if today has no logs yet).
int currentStreak(Set<DateTime> loggedDays, {DateTime? today}) {
  final now = dateOnly(today ?? DateTime.now());
  var day = loggedDays.contains(now)
      ? now
      : now.subtract(const Duration(days: 1));
  var streak = 0;
  while (loggedDays.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The longest run of consecutive logged days ever recorded.
int bestStreak(Set<DateTime> loggedDays) {
  if (loggedDays.isEmpty) return 0;
  final sorted = loggedDays.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    run = gap == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}