import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/core/sync/sync_merge.dart';
import 'package:my_bodybuilding_program/features/profile/domain/body_weight.dart';
import 'package:my_bodybuilding_program/features/progress/domain/stats.dart';
import 'package:my_bodybuilding_program/features/progress/domain/streak.dart';

void main() {
  group('StreakRule', () {
    // November 2026: the 2nd, 9th and 16th are Mondays.
    DateTime d(int day, [int month = 11]) => DateTime(2026, month, day, 18);

    test('weeks run Monday to Sunday', () {
      expect(StreakRule.weekStart(d(15)), DateTime(2026, 11, 9)); // Sunday
      expect(StreakRule.weekStart(d(16)), DateTime(2026, 11, 16)); // Monday
      expect(StreakRule.weekStart(DateTime(2026, 3)), DateTime(2026, 2, 23));
    });

    test('no workouts, no streak', () {
      final s = StreakRule.compute([], weeklyTarget: 3, today: d(15));
      expect(s.current, 0);
      expect(s.best, 0);
      expect(s.thisWeek, 0);
      expect(s.weekReached, isFalse);
    });

    test('counts consecutive weeks that reached the target', () {
      final s = StreakRule.compute(
        [d(2), d(4), d(6), d(9), d(11), d(13)],
        weeklyTarget: 3,
        today: d(15),
      );
      expect(s.current, 2);
      expect(s.best, 2);
      expect(s.thisWeek, 3);
      expect(s.weekReached, isTrue);
    });

    test('the current week does not break the streak before it ends', () {
      // Two full weeks, and only one workout so far this week.
      final s = StreakRule.compute(
        [d(2), d(4), d(6), d(9), d(11), d(13), d(16)],
        weeklyTarget: 3,
        today: d(17),
      );
      expect(s.current, 2);
      expect(s.thisWeek, 1);
      expect(s.weekReached, isFalse);
    });

    test('the current week counts as soon as the target is reached', () {
      final s = StreakRule.compute(
        [d(2), d(4), d(6), d(9), d(11), d(13), d(16), d(17), d(18)],
        weeklyTarget: 3,
        today: d(18),
      );
      expect(s.current, 3);
    });

    test('a missed week resets the current streak but not the best', () {
      final s = StreakRule.compute(
        [
          d(5, 10), d(6, 10), d(7, 10), // week of 5 Oct
          d(12, 10), d(13, 10), d(14, 10), // week of 12 Oct
          d(19, 10), d(20, 10), d(21, 10), // week of 19 Oct
          d(27, 10), // week of 26 Oct: missed
          d(2), d(3), d(4), // week of 2 Nov
          d(9), d(10), d(11), // week of 9 Nov
        ],
        weeklyTarget: 3,
        today: d(15),
      );
      expect(s.current, 2);
      expect(s.best, 3);
    });

    test('rest days never matter, only the weekly count', () {
      // Three workouts on the same weekend still make the week.
      final s = StreakRule.compute(
        [d(13), d(14), d(15)],
        weeklyTarget: 3,
        today: d(15),
      );
      expect(s.current, 1);
    });

    test('follows the weekly target setting', () {
      final dates = [d(2), d(4), d(9), d(11)];
      expect(
        StreakRule.compute(dates, weeklyTarget: 2, today: d(15)).current,
        2,
      );
      expect(
        StreakRule.compute(dates, weeklyTarget: 3, today: d(15)).current,
        0,
      );
    });

    test('an old streak that ended is not current', () {
      final s = StreakRule.compute(
        [d(5, 10), d(6, 10), d(7, 10)],
        weeklyTarget: 3,
        today: d(15),
      );
      expect(s.current, 0);
      expect(s.best, 1);
    });

    test('streaks cross a year boundary', () {
      final s = StreakRule.compute(
        [
          DateTime(2026, 12, 28),
          DateTime(2026, 12, 30),
          DateTime(2027, 1, 2),
          DateTime(2027, 1, 4),
          DateTime(2027, 1, 5),
          DateTime(2027, 1, 6),
        ],
        weeklyTarget: 3,
        today: DateTime(2027, 1, 7),
      );
      expect(s.current, 2);
    });
  });

  group('StatsRule', () {
    WorkoutSummary w(String id, DateTime start, int minutes, int sets) =>
        WorkoutSummary(
          id: id,
          sessionName: 'Push',
          startedAt: start,
          durationSeconds: minutes * 60,
          setCount: sets,
          exerciseCount: 5,
        );

    final workouts = [
      w('a', DateTime(2026, 9, 20, 18), 50, 15),
      w('b', DateTime(2026, 10, 5, 18), 60, 18),
      w('c', DateTime(2026, 10, 25, 18), 55, 17),
      w('d', DateTime(2026, 11, 3, 18), 45, 14),
    ];

    test('totals over everything', () {
      final stats = StatsRule.compute(workouts, DateTime(2026, 11, 15));
      expect(stats.total.workouts, 4);
      expect(stats.total.seconds, 210 * 60);
      expect(stats.total.sets, 64);
    });

    test('this month against last month', () {
      final stats = StatsRule.compute(workouts, DateTime(2026, 11, 15));
      expect(stats.thisMonth.workouts, 1);
      expect(stats.thisMonth.seconds, 45 * 60);
      expect(stats.lastMonth.workouts, 2);
      expect(stats.lastMonth.seconds, 115 * 60);
    });

    test('January compares with December of the year before', () {
      final stats = StatsRule.compute([
        w('x', DateTime(2026, 12, 30, 18), 40, 10),
        w('y', DateTime(2027, 1, 2, 18), 30, 9),
      ], DateTime(2027, 1, 10));
      expect(stats.thisMonth.workouts, 1);
      expect(stats.lastMonth.workouts, 1);
    });

    test('totals of one month', () {
      final october = StatsRule.ofMonth(workouts, DateTime(2026, 10));
      expect(october.workouts, 2);
      expect(october.sets, 35);
    });
  });

  group('BodyWeightTrend', () {
    BodyWeight e(String id, int day, double kg) => BodyWeight(
      id: id,
      measuredAt: DateTime.utc(2026, 11, day),
      weightKg: kg,
    );

    test('latest entry', () {
      expect(BodyWeightTrend.latest([e('a', 1, 80), e('b', 9, 79)])!.id, 'b');
      expect(BodyWeightTrend.latest(const []), isNull);
    });

    test('change against the entry that is at least N days older', () {
      final entries = [e('a', 1, 80), e('b', 8, 79.4), e('c', 15, 79.1)];
      expect(BodyWeightTrend.changeOver(entries, days: 7), -0.3);
      expect(BodyWeightTrend.changeOver(entries, days: 14), -0.9);
    });

    test('a short log compares with its oldest entry', () {
      final entries = [e('a', 10, 80), e('b', 15, 80.6)];
      expect(BodyWeightTrend.changeOver(entries, days: 30), 0.6);
    });

    test('needs two entries', () {
      expect(BodyWeightTrend.changeOver([e('a', 1, 80)], days: 30), isNull);
    });

    test('change of each entry from the previous one', () {
      final changes = BodyWeightTrend.changes([
        e('c', 15, 79.1),
        e('a', 1, 80),
        e('b', 8, 79.4),
      ]);
      expect(changes, {'b': -0.6, 'c': -0.3});
    });
  });

  group('SyncMerge (last write wins per row)', () {
    final t1 = DateTime.utc(2026, 11);
    final t2 = DateTime.utc(2026, 11, 2);
    RowVersion row(String id, DateTime at, {bool dirty = false}) =>
        RowVersion(id: id, updatedAt: at, dirty: dirty);

    test('rows only on one side are copied to the other', () {
      final plan = SyncMerge.plan(
        local: [row('local-only', t1)],
        remote: [row('remote-only', t1)],
      );
      expect(plan.push, {'local-only'});
      expect(plan.pull, {'remote-only'});
    });

    test('the newer side wins', () {
      final plan = SyncMerge.plan(
        local: [row('a', t2), row('b', t1)],
        remote: [row('a', t1), row('b', t2)],
      );
      expect(plan.push, {'a'});
      expect(plan.pull, {'b'});
    });

    test('identical rows do nothing unless the local one is dirty', () {
      final plan = SyncMerge.plan(
        local: [row('same', t1), row('dirty', t1, dirty: true)],
        remote: [row('same', t1), row('dirty', t1)],
      );
      expect(plan.push, {'dirty'});
      expect(plan.pull, isEmpty);
    });

    test('restore on a new phone pulls everything', () {
      final plan = SyncMerge.plan(
        local: const [],
        remote: [row('a', t1), row('b', t2)],
      );
      expect(plan.pull, {'a', 'b'});
      expect(plan.push, isEmpty);
    });
  });
}
