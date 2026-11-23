import 'package:flutter_test/flutter_test.dart';
import 'package:planit/domain/streak.dart';

DateTime d(int year, int month, int day) => DateTime(year, month, day);

void main() {
  group('current streak', () {
    test('counts consecutive days ending today', () {
      final days = {
        d(2026, 11, 21),
        d(2026, 11, 22),
        d(2026, 11, 23),
      };
      expect(currentStreak(days, today: d(2026, 11, 23)), 3);
    });

    test('continues from yesterday when today has no logs', () {
      final days = {d(2026, 11, 21), d(2026, 11, 22)};
      expect(currentStreak(days, today: d(2026, 11, 23)), 2);
    });

    test('breaks on a gap', () {
      final days = {d(2026, 11, 20), d(2026, 11, 23)};
      expect(currentStreak(days, today: d(2026, 11, 23)), 1);
    });

    test('is zero with no logs', () {
      expect(currentStreak({}, today: d(2026, 11, 23)), 0);
    });
  });

  group('best streak', () {
    test('finds the longest run anywhere in history', () {
      final days = {
        d(2026, 11, 1),
        d(2026, 11, 2),
        d(2026, 11, 3),
        d(2026, 11, 10),
        d(2026, 11, 20),
        d(2026, 11, 21),
      };
      expect(bestStreak(days), 3);
    });

    test('is zero with no logs', () {
      expect(bestStreak({}), 0);
    });
  });
}