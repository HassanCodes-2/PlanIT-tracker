import 'package:flutter_test/flutter_test.dart';
import 'package:planit/data/db/app_database.dart';
import 'package:planit/domain/deed_schedule.dart';
import 'package:planit/domain/stats.dart';

Deed deed({
  required int id,
  String frequency = 'daily',
  String? weekdays,
  int? times,
}) {
  return Deed(
    id: id,
    name: 'Deed $id',
    frequencyType: frequency,
    weekdays: weekdays,
    timesPerPeriod: times,
    reasonsEnabled: false,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

DeedLog log({
  required int id,
  required int deedId,
  required DateTime day,
  required String status,
}) {
  return DeedLog(
    id: id,
    deedId: deedId,
    day: day,
    status: status,
    loggedAt: day,
  );
}

void main() {
  group('deed schedule', () {
    test('daily deeds are scheduled every day', () {
      final daily = deed(id: 1);
      expect(isScheduledOn(daily, DateTime(2026, 11, 23)), isTrue);
      expect(isScheduledOn(daily, DateTime(2026, 11, 29)), isTrue);
    });

    test('weekday deeds respect selected weekdays', () {
      final weekdayDeed =
          deed(id: 2, frequency: 'weekdays', weekdays: '1,3,5');
      expect(isScheduledOn(weekdayDeed, DateTime(2026, 11, 23)), isTrue); // Mon
      expect(isScheduledOn(weekdayDeed, DateTime(2026, 11, 24)), isFalse); // Tue
      expect(isScheduledOn(weekdayDeed, DateTime(2026, 11, 25)), isTrue); // Wed
    });

    test('count-based deeds are available every day', () {
      final twice = deed(id: 3, frequency: 'times_per_week', times: 2);
      expect(isScheduledOn(twice, DateTime(2026, 11, 23)), isTrue);
      expect(isScheduledOn(twice, DateTime(2026, 11, 24)), isTrue);
    });

    test('daily expected occurrences for a week', () {
      final daily = deed(id: 4);
      expect(
        expectedOccurrences(
          daily,
          DateTime(2026, 11, 23),
          DateTime(2026, 11, 29),
        ),
        7,
      );
    });

    test('weekday expected occurrences for a week', () {
      final weekdayDeed =
          deed(id: 5, frequency: 'weekdays', weekdays: '1,3,5');
      expect(
        expectedOccurrences(
          weekdayDeed,
          DateTime(2026, 11, 23),
          DateTime(2026, 11, 29),
        ),
        3,
      );
    });

    test('times-per-week expected occurrences over two weeks', () {
      final twice = deed(id: 6, frequency: 'times_per_week', times: 3);
      expect(
        expectedOccurrences(
          twice,
          DateTime(2026, 11, 23),
          DateTime(2026, 12, 6),
        ),
        6,
      );
    });
  });

  group('stats', () {
    test('counts done, late, skipped and derives missed', () {
      final daily = deed(id: 10);
      final logs = [
        log(id: 1, deedId: 10, day: DateTime(2026, 11, 23), status: 'done'),
        log(id: 2, deedId: 10, day: DateTime(2026, 11, 24), status: 'late'),
        log(id: 3, deedId: 10, day: DateTime(2026, 11, 25), status: 'skipped'),
      ];

      final result = computeStats(
        deeds: [daily],
        logs: logs,
        from: DateTime(2026, 11, 23),
        to: DateTime(2026, 11, 29),
      );

      expect(result.expected, 7);
      expect(result.done, 1);
      expect(result.late, 1);
      expect(result.skipped, 1);
      expect(result.missed, 4);
      expect(result.deeds.single.completionRate, closeTo(2 / 7, 0.0001));
    });

    test('ignores logs outside the period', () {
      final daily = deed(id: 11);
      final logs = [
        log(id: 1, deedId: 11, day: DateTime(2026, 11, 1), status: 'done'),
        log(id: 2, deedId: 11, day: DateTime(2026, 11, 23), status: 'done'),
      ];

      final result = computeStats(
        deeds: [daily],
        logs: logs,
        from: DateTime(2026, 11, 23),
        to: DateTime(2026, 11, 23),
      );

      expect(result.expected, 1);
      expect(result.done, 1);
      expect(result.deeds.single.completionRate, 1.0);
    });
  });
}