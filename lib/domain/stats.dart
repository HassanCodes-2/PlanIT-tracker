import '../data/db/app_database.dart';
import 'deed_schedule.dart';
import 'enums.dart';

enum StatsPeriodType {
  weeks('Weeks', 7),
  months('Months', 30),
  years('Years', 365),
  all('All time', 3650);

  const StatsPeriodType(this.label, this.days);

  final String label;
  final int days;
}

class DeedStats {
  const DeedStats({
    required this.deed,
    required this.expected,
    required this.done,
    required this.late,
    required this.skipped,
  });

  final Deed deed;
  final int expected;
  final int done;
  final int late;
  final int skipped;

  int get missed => (expected - done - late - skipped).clamp(0, expected);

  int get logged => done + late + skipped;

  double get completionRate => expected == 0 ? 0 : logged / expected;

  double get onTimeRate => expected == 0 ? 0 : done / expected;
}

class StatsResult {
  const StatsResult(this.deeds);

  final List<DeedStats> deeds;

  int get expected => deeds.fold(0, (sum, item) => sum + item.expected);
  int get done => deeds.fold(0, (sum, item) => sum + item.done);
  int get late => deeds.fold(0, (sum, item) => sum + item.late);
  int get skipped => deeds.fold(0, (sum, item) => sum + item.skipped);
  int get missed => (expected - done - late - skipped).clamp(0, expected);

  double _pct(int value) => expected == 0 ? 0 : value / expected * 100;

  double get donePct => _pct(done);
  double get latePct => _pct(late);
  double get skippedPct => _pct(skipped);
  double get missedPct => _pct(missed);
}

StatsResult computeStats({
  required List<Deed> deeds,
  required List<DeedLog> logs,
  required DateTime from,
  required DateTime to,
}) {
  final logsByDeed = <int, List<DeedLog>>{};
  for (final log in logs) {
    final day = dateOnly(log.day);
    if (day.isBefore(dateOnly(from)) || day.isAfter(dateOnly(to))) continue;
    logsByDeed.putIfAbsent(log.deedId, () => []).add(log);
  }

  final result = <DeedStats>[];
  for (final deed in deeds) {
    final expected = expectedOccurrences(deed, from, to);
    if (expected == 0) continue;

    var done = 0;
    var late = 0;
    var skipped = 0;
    for (final log in logsByDeed[deed.id] ?? const <DeedLog>[]) {
      switch (LogStatus.fromDb(log.status)) {
        case LogStatus.done:
          done++;
        case LogStatus.late:
          late++;
        case LogStatus.skipped:
          skipped++;
      }
    }

    result.add(
      DeedStats(
        deed: deed,
        expected: expected,
        done: done,
        late: late,
        skipped: skipped,
      ),
    );
  }

  result.sort((a, b) => b.completionRate.compareTo(a.completionRate));
  return StatsResult(result);
}