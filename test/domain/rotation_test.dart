import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/features/program/domain/rotation.dart';

void main() {
  const loop = ['push', 'pull', 'legs'];

  group('resolve', () {
    test('empty program has no next session', () {
      expect(Rotation.resolve([], null), isNull);
      expect(Rotation.resolve([], 'push'), isNull);
    });

    test('keeps a pointer that is in the loop', () {
      expect(Rotation.resolve(loop, 'pull'), 'pull');
    });

    test('falls back to the first session', () {
      expect(Rotation.resolve(loop, null), 'push');
      expect(Rotation.resolve(loop, 'deleted'), 'push');
    });
  });

  group('afterWorkout', () {
    test('finishing the suggested session moves to the following one', () {
      expect(Rotation.afterWorkout(loop, 'push', 'push'), 'pull');
    });

    test('wraps around at the end of the loop', () {
      expect(Rotation.afterWorkout(loop, 'legs', 'legs'), 'push');
    });

    test('follows what was actually done, not what was suggested', () {
      // Push was next, but Legs was done: next is the session after Legs.
      expect(Rotation.afterWorkout(loop, 'push', 'legs'), 'push');
      expect(Rotation.afterWorkout(loop, 'legs', 'push'), 'pull');
    });

    test('an empty workout does not move the pointer', () {
      expect(Rotation.afterWorkout(loop, 'pull', null), 'pull');
    });

    test('a workout from a deleted session does not move the pointer', () {
      expect(Rotation.afterWorkout(loop, 'pull', 'gone'), 'pull');
    });

    test('a single-session loop points to itself', () {
      expect(Rotation.afterWorkout(['only'], 'only', 'only'), 'only');
    });
  });

  group('afterSkip', () {
    test('moves to the following session', () {
      expect(Rotation.afterSkip(loop, 'push'), 'pull');
      expect(Rotation.afterSkip(loop, 'legs'), 'push');
    });

    test('skips from the first session when the pointer is unset', () {
      expect(Rotation.afterSkip(loop, null), 'pull');
    });

    test('does nothing on an empty program', () {
      expect(Rotation.afterSkip([], null), isNull);
    });
  });

  group('afterDelete', () {
    test('deleting another session keeps the pointer', () {
      expect(Rotation.afterDelete(loop, 'push', 'legs'), 'push');
    });

    test('deleting the next session points to the one after it', () {
      expect(Rotation.afterDelete(loop, 'pull', 'pull'), 'legs');
      expect(Rotation.afterDelete(loop, 'legs', 'legs'), 'push');
    });

    test('deleting the last remaining session empties the pointer', () {
      expect(Rotation.afterDelete(['only'], 'only', 'only'), isNull);
    });
  });

  test('placeOf gives the 1-based place in the loop', () {
    expect(Rotation.placeOf(loop, 'pull'), 2);
    expect(Rotation.placeOf(loop, null), 1);
    expect(Rotation.placeOf([], null), isNull);
  });
}
