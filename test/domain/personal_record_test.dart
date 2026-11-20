import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:my_bodybuilding_program/features/progress/domain/personal_record.dart';

void main() {
  var n = 0;
  PersonalRecord pr({
    required int day,
    double? load,
    String? unitId,
    int? reps,
    int? seconds,
  }) => PersonalRecord(
    id: 'pr${n++}',
    exerciseId: 'ex',
    achievedAt: DateTime.utc(2026, 11, day),
    load: load,
    unitId: load == null ? null : unitId ?? 'kg',
    reps: reps,
    seconds: seconds,
  );

  group('PersonalRecordDraft.errorFor', () {
    PersonalRecordDraft draft({
      double? load,
      String? unitId = 'kg',
      int? reps,
      int? seconds,
    }) => PersonalRecordDraft(
      achievedAt: DateTime.utc(2026),
      load: load,
      unitId: unitId,
      reps: reps,
      seconds: seconds,
    );

    test('reps exercise: a load, reps or both', () {
      expect(draft(load: 120).errorFor(Measure.reps), isNull);
      expect(draft(reps: 15).errorFor(Measure.reps), isNull);
      expect(draft(load: 100, reps: 5).errorFor(Measure.reps), isNull);
      expect(draft().errorFor(Measure.reps), PrDraftError.repsOrLoadNeeded);
      expect(
        draft(reps: 5, seconds: 30).errorFor(Measure.reps),
        PrDraftError.timeNotAllowed,
      );
      expect(draft(reps: 0).errorFor(Measure.reps), PrDraftError.repsInvalid);
    });

    test('time exercise: a time, and an optional load', () {
      expect(draft(seconds: 90).errorFor(Measure.time), isNull);
      expect(draft(seconds: 60, load: 20).errorFor(Measure.time), isNull);
      expect(draft(load: 20).errorFor(Measure.time), PrDraftError.timeNeeded);
      expect(
        draft(seconds: 60, reps: 3).errorFor(Measure.time),
        PrDraftError.repsNotAllowed,
      );
      expect(
        draft(seconds: 0).errorFor(Measure.time),
        PrDraftError.timeInvalid,
      );
    });

    test('a load needs its unit', () {
      expect(
        draft(load: 100, unitId: null).errorFor(Measure.reps),
        PrDraftError.unitMissing,
      );
    });

    test('normalizedFor drops what does not apply', () {
      final clean = PersonalRecordDraft(
        achievedAt: DateTime.utc(2026),
        unitId: 'kg',
        reps: 12,
        seconds: 40,
        note: '  ',
      ).normalizedFor(Measure.reps);
      expect(clean.unitId, isNull);
      expect(clean.seconds, isNull);
      expect(clean.reps, 12);
      expect(clean.note, isNull);
    });
  });

  group('PrRule.bests', () {
    test(
      'loaded PRs: heaviest load, then most reps; a load alone is 1 rep',
      () {
        final records = [
          pr(day: 1, load: 100, reps: 3),
          pr(day: 2, load: 110),
          pr(day: 3, load: 110, reps: 2),
          pr(day: 4, load: 105, reps: 5),
        ];
        final best = PrRule.bests(records, Measure.reps).single;
        expect(best.unitId, 'kg');
        expect(best.record, records[2]);
      },
    );

    test('ties keep the earliest PR', () {
      final records = [pr(day: 1, load: 100), pr(day: 5, load: 100)];
      expect(PrRule.currentBest(records, Measure.reps), records.first);
    });

    test('units are never compared; latest series first', () {
      final records = [
        pr(day: 1, load: 120, unitId: 'kg'),
        pr(day: 2, reps: 20),
        pr(day: 3, load: 9, unitId: 'level'),
        pr(day: 4, load: 7, unitId: 'level'),
      ];
      final bests = PrRule.bests(records, Measure.reps);
      expect(bests.map((b) => b.unitId), ['level', null, 'kg']);
      expect(bests.first.record.load, 9);
      expect(bests[1].record.reps, 20);
      expect(PrRule.currentBest(records, Measure.reps)!.load, 9);
    });

    test('time PRs: longest time, then heaviest load', () {
      final records = [
        pr(day: 1, seconds: 90),
        pr(day: 2, seconds: 80),
        pr(day: 3, seconds: 60, load: 10),
        pr(day: 4, seconds: 60, load: 20),
      ];
      final bests = PrRule.bests(records, Measure.time);
      expect(bests.first.unitId, 'kg');
      expect(bests.first.record.load, 20);
      expect(bests[1].record.seconds, 90);
    });

    test('no PR: no best', () {
      expect(PrRule.bests(const [], Measure.reps), isEmpty);
      expect(PrRule.currentBest(const [], Measure.time), isNull);
    });
  });

  test('PrRule.latest: newest first, at most count', () {
    final records = [for (var d = 1; d <= 7; d++) pr(day: d, reps: d)];
    final latest = PrRule.latest(records.reversed.toList()..shuffle(), 5);
    expect(latest.map((r) => r.reps), [7, 6, 5, 4, 3]);
  });

  test('compare ranks within a series', () {
    expect(
      PrRule.compare(pr(day: 1, reps: 12), pr(day: 1, reps: 10), Measure.reps),
      greaterThan(0),
    );
    expect(
      PrRule.compare(
        pr(day: 1, seconds: 30, load: 5),
        pr(day: 1, seconds: 31),
        Measure.time,
      ),
      lessThan(0),
    );
  });
}
