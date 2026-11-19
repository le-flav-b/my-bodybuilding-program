import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/progress/domain/calendar.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_scale.dart';

void main() {
  group('CalendarRule', () {
    final today = DateTime(2026, 11, 15); // a Sunday

    test('weeks cover the month, Monday first', () {
      final weeks = CalendarRule.weeks(
        DateTime(2026, 11, 20),
        workoutDates: const [],
        weeklyTarget: 3,
        today: today,
      );
      expect(weeks.first.monday, DateTime(2026, 10, 26));
      expect(weeks.last.days.last, DateTime(2026, 12, 6));
      expect(weeks, hasLength(6));
      expect(weeks.every((w) => w.days.length == 7), isTrue);
    });

    test('week status: reached, missed, current, future', () {
      final weeks = CalendarRule.weeks(
        DateTime(2026, 11),
        workoutDates: [
          DateTime(2026, 10, 28),
          DateTime(2026, 10, 30),
          DateTime(2026, 11),
          DateTime(2026, 11, 3),
          DateTime(2026, 11, 10),
        ],
        weeklyTarget: 3,
        today: DateTime(2026, 11, 11),
      );
      expect(weeks[0].status, WeekStatus.reached);
      expect(weeks[1].status, WeekStatus.missed);
      expect(weeks[2].status, WeekStatus.current);
      expect(weeks[3].status, WeekStatus.future);
    });

    test('the current week shows reached once the target is met', () {
      final weeks = CalendarRule.weeks(
        today,
        workoutDates: [DateTime(2026, 11, 9), DateTime(2026, 11, 14)],
        weeklyTarget: 2,
        today: today,
      );
      expect(
        weeks.firstWhere((w) => w.monday == DateTime(2026, 11, 9)).status,
        WeekStatus.reached,
      );
    });

    test('perDay counts two workouts on one day', () {
      final days = CalendarRule.perDay([
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 6, 18),
        DateTime(2026, 11, 7, 9),
      ]);
      expect(days[DateTime(2026, 11, 6)], 2);
      expect(days[DateTime(2026, 11, 7)], 1);
    });
  });

  group('ChartScale', () {
    test('round bounds and step', () {
      final s = ChartScale.nice(32.5, 42.5);
      expect(s.step, 5);
      expect(s.min, 30);
      expect(s.max, 45);
      expect(s.ticks, [30, 35, 40, 45]);
    });

    test('small values use a fractional step', () {
      final s = ChartScale.nice(4.5, 7);
      expect(s.min, lessThanOrEqualTo(4.5));
      expect(s.max, greaterThanOrEqualTo(7));
      expect(s.intervals, greaterThanOrEqualTo(3));
    });

    test('a flat series gets a band around its value', () {
      final s = ChartScale.nice(40, 40);
      expect(s.min, lessThan(40));
      expect(s.max, greaterThan(40));
    });

    test('normalize and valueAt are inverse', () {
      final s = ChartScale.nice(0, 100);
      expect(s.normalize(s.valueAt(0.3)), closeTo(0.3, 1e-9));
      expect(s.normalize(s.min), 0);
      expect(s.normalize(s.max), 1);
    });

    test('negative loads (assisted)', () {
      final s = ChartScale.nice(-20, -5);
      expect(s.min, lessThanOrEqualTo(-20));
      expect(s.max, greaterThanOrEqualTo(-5));
    });
  });
}
