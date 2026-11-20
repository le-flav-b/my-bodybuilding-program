import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/progress/domain/bests.dart';
import 'package:my_bodybuilding_program/features/progress/domain/chart_series.dart';
import 'package:my_bodybuilding_program/features/progress/domain/last_time.dart';
import 'package:my_bodybuilding_program/features/progress/domain/logged_set.dart';

import '../helpers/fixtures.dart';

void main() {
  group('Bests.current', () {
    test('heaviest load per unit, whatever the reps', () {
      final records = Bests.current([
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, reps: 3, load: 50),
        logged('w3', 5, reps: 12, load: 6, unit: 'level'),
        logged('w4', 7, reps: 8, load: 7, unit: 'level'),
      ]);
      expect(records, hasLength(2));
      final byKey = {for (final r in records) r.series: r.value};
      expect(byKey[const SeriesKey.load(unitId: 'kg')], 50);
      expect(byKey[const SeriesKey.load(unitId: 'level')], 7);
    });

    test('most reps counts only sets with no load', () {
      final records = Bests.current([
        logged('w1', 1, exercise: 'pullup', reps: 8),
        logged('w2', 3, exercise: 'pullup', reps: 11),
        logged('w3', 5, exercise: 'pullup', reps: 20, load: 5),
      ]);
      final byKey = {for (final r in records) r.series: r.value};
      expect(byKey[const SeriesKey.reps()], 11);
      expect(byKey[const SeriesKey.load(unitId: 'kg')], 5);
    });

    test('longest hold for time-based exercises', () {
      final records = Bests.current([
        logged('w1', 1, exercise: 'plank', measure: Measure.time, seconds: 60),
        logged('w2', 3, exercise: 'plank', measure: Measure.time, seconds: 80),
      ]);
      expect(records.single.series, const SeriesKey.time());
      expect(records.single.value, 80);
    });

    test('the earliest set holds a tied record', () {
      final first = logged('w1', 1, reps: 5, load: 50, id: 'first');
      final records = Bests.current([
        first,
        logged('w2', 3, reps: 5, load: 50, id: 'second'),
      ]);
      expect(records.single.set.setId, 'first');
    });

    test('assisted (negative) loads: less assistance is the record', () {
      final records = Bests.current([
        logged('w1', 1, exercise: 'dip', reps: 8, load: -20),
        logged('w2', 3, exercise: 'dip', reps: 8, load: -10),
      ]);
      expect(records.single.value, -10);
    });
  });

  group('Bests.events', () {
    test('the first workout sets the baseline without a record', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        logged('w1', 1, reps: 8, load: 45, order: 1),
      ]);
      expect(events, isEmpty);
    });

    test('beating the previous record is an event with the old value', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, reps: 10, load: 42.5, id: 'pr'),
      ]);
      expect(events.single.setId, 'pr');
      expect(events.single.value, 42.5);
      expect(events.single.previous, 40);
    });

    test('equalling a record is not a new record', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, reps: 10, load: 40),
      ]);
      expect(events, isEmpty);
    });

    test('within a workout each set must beat the earlier ones', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, reps: 10, load: 42.5, id: 'a'),
        logged('w2', 3, reps: 8, load: 42.5, order: 1, id: 'b'),
        logged('w2', 3, reps: 6, load: 45, order: 2, id: 'c'),
      ]);
      expect(events.map((e) => e.setId), ['a', 'c']);
      expect(events.last.previous, 42.5);
    });

    test('each unit has its own records', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        // First time in levels: baseline only, even though 6 < 40.
        logged('w2', 3, reps: 10, load: 6, unit: 'level'),
        logged('w3', 5, reps: 10, load: 7, unit: 'level', id: 'level-pr'),
        logged('w4', 7, reps: 10, load: 39),
      ]);
      expect(events.single.setId, 'level-pr');
      expect(events.single.series, const SeriesKey.load(unitId: 'level'));
    });

    test('exercises do not share records', () {
      final events = Bests.events([
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, exercise: 'squat', reps: 5, load: 100),
      ]);
      expect(events, isEmpty);
    });

    test('is computed in chronological order whatever the input order', () {
      final events = Bests.events([
        logged('w2', 3, reps: 10, load: 42.5, id: 'pr'),
        logged('w1', 1, reps: 10, load: 40),
      ]);
      expect(events.single.setId, 'pr');
    });

    test('deleting the old best makes a later set the record (recompute)', () {
      final sets = [
        logged('w1', 1, reps: 10, load: 40),
        logged('w2', 3, reps: 10, load: 50, id: 'typo'),
        logged('w3', 5, reps: 10, load: 45, id: 'real'),
      ];
      expect(Bests.events(sets).map((e) => e.setId), ['typo']);
      final edited = sets.where((s) => s.setId != 'typo');
      expect(Bests.events(edited).map((e) => e.setId), ['real']);
    });
  });

  test('Bests.ofWorkout keeps the best per series with the old record', () {
    final events = Bests.events([
      logged('w1', 1, reps: 10, load: 40),
      logged('w2', 3, reps: 10, load: 42.5),
      logged('w2', 3, reps: 6, load: 45, order: 1),
      logged('w2', 3, exercise: 'pullup', reps: 9),
    ]);
    final ofWorkout = Bests.ofWorkout(events, 'w2');
    expect(ofWorkout.single.value, 45);
    expect(ofWorkout.single.previous, 40);
    expect(Bests.ofWorkout(events, 'w1'), isEmpty);
  });

  test('Bests.latest returns the newest events first', () {
    final events = Bests.events([
      for (var i = 0; i < 8; i++)
        logged('w$i', 1 + i * 2, reps: 10, load: 40.0 + i),
    ]);
    final latest = Bests.latest(events, 5);
    expect(latest, hasLength(5));
    expect(latest.first.value, 47);
    expect(latest.last.value, 43);
  });

  group('ChartSeriesBuilder', () {
    final sets = [
      logged('w1', 1, reps: 10, load: 40),
      logged('w1', 1, reps: 8, load: 45, order: 1),
      // The machine was taken: levels on another one.
      logged('w2', 5, reps: 10, load: 6, unit: 'level'),
      logged('w3', 9, reps: 10, load: 47.5),
      logged('w4', 13, reps: 10, load: 7, unit: 'level'),
      logged('w5', 17, reps: 10, load: 45),
      // A bodyweight set of the same exercise.
      logged('w5', 17, reps: 15, order: 1),
    ];

    test('one point per workout: the best load of each unit', () {
      final series = ChartSeriesBuilder.build(sets);
      final kgSeries = series.firstWhere(
        (s) => s.key == const SeriesKey.load(unitId: 'kg'),
      );
      expect(kgSeries.points.map((p) => p.value), [45, 47.5, 45]);
      expect(kgSeries.points.first.bestSet.reps, 8);
    });

    test('units share the timeline but each has its own series', () {
      final series = ChartSeriesBuilder.build(sets);
      expect(series.map((s) => s.key), [
        const SeriesKey.load(unitId: 'kg'),
        const SeriesKey.load(unitId: 'level'),
        const SeriesKey.reps(),
      ]);
      final levels = series[1].points;
      expect(levels.map((p) => p.value), [6, 7]);
      expect(levels.map((p) => p.date.day), [5, 13]);
    });

    test('series come in order of first use', () {
      final series = ChartSeriesBuilder.build([
        logged('w1', 1, reps: 10, load: 6, unit: 'level'),
        logged('w2', 3, reps: 10, load: 40),
      ]);
      expect(series.first.key, const SeriesKey.load(unitId: 'level'));
    });

    test('record points beat every earlier point of their own unit', () {
      final series = ChartSeriesBuilder.build(sets);
      expect(series[0].points.map((p) => p.isRecord), [false, true, false]);
      expect(series[1].points.map((p) => p.isRecord), [false, true]);
    });

    test('sets with no load plot the best reps', () {
      final series = ChartSeriesBuilder.build([
        logged('w1', 1, exercise: 'pullup', reps: 8),
        logged('w1', 1, exercise: 'pullup', reps: 6, order: 1),
        logged('w2', 3, exercise: 'pullup', reps: 9),
      ]);
      expect(series.single.key, const SeriesKey.reps());
      expect(series.single.points.map((p) => p.value), [8, 9]);
    });

    test('time-based exercises plot the best time', () {
      final series = ChartSeriesBuilder.build([
        logged('w1', 1, exercise: 'plank', measure: Measure.time, seconds: 60),
        logged(
          'w1',
          1,
          exercise: 'plank',
          measure: Measure.time,
          seconds: 75,
          order: 1,
        ),
      ]);
      expect(series.single.key, const SeriesKey.time());
      expect(series.single.points.single.value, 75);
    });

    test('the range cuts the timeline but keeps records relative to all', () {
      final series = ChartSeriesBuilder.build(
        sets,
        from: DateTime.utc(2026, 1, 8),
      );
      final kgSeries = series.first;
      expect(kgSeries.points.map((p) => p.value), [47.5, 45]);
      expect(kgSeries.points.first.isRecord, isTrue);
    });

    test('range starts', () {
      final now = DateTime.utc(2026, 11, 15);
      expect(ChartRange.oneMonth.start(now), DateTime.utc(2026, 10, 15));
      expect(ChartRange.oneYear.start(now), DateTime.utc(2025, 11, 15));
      expect(ChartRange.all.start(now), isNull);
    });

    test('sparkline follows the most used series', () {
      expect(ChartSeriesBuilder.sparkline(sets), [45, 47.5, 45]);
      expect(ChartSeriesBuilder.sparkline(const []), isEmpty);
    });
  });

  group('LastTime', () {
    final sets = [
      logged('w1', 1, reps: 10, load: 40),
      logged('w2', 5, reps: 10, load: 42.5, id: 'a'),
      logged('w2', 5, reps: 9, load: 42.5, order: 1, id: 'b'),
    ];

    test('returns the sets of the most recent workout, in order', () {
      expect(LastTime.sets(sets).map((s) => s.setId), ['a', 'b']);
    });

    test('can leave the current workout out', () {
      expect(LastTime.sets(sets, excludeWorkoutId: 'w2').single.load, 40);
      expect(LastTime.sets(const []), isEmpty);
    });

    test('matches a set number, falling back to the last set done', () {
      final last = LastTime.sets(sets);
      expect(LastTime.forSetIndex(last, 0)!.setId, 'a');
      expect(LastTime.forSetIndex(last, 1)!.setId, 'b');
      expect(LastTime.forSetIndex(last, 3)!.setId, 'b');
      expect(LastTime.forSetIndex(const [], 0), isNull);
    });
  });
}
