import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/notifications/reminder_scheduler.dart';
import 'package:my_bodybuilding_program/features/settings/domain/app_settings.dart';
import 'package:my_bodybuilding_program/features/settings/domain/reminders.dart';
import 'package:my_bodybuilding_program/features/settings/presentation/reminder_runtime.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;

  setUpAll(() {
    tz_data.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  /// A local time in Paris, as a UTC instant.
  DateTime at(
    int month,
    int day,
    int hour, [
    int minute = 0,
    int year = 2026,
  ]) => tz.TZDateTime(paris, year, month, day, hour, minute).toUtc();

  /// November 2026: the 16th is a Monday.
  const training = ReminderSettings(trainingEnabled: true);
  const weighIn = ReminderSettings(weighInEnabled: true);

  List<ReminderOccurrence> plan(
    ReminderSettings settings,
    DateTime now, {
    ReminderFacts facts = const ReminderFacts(),
  }) => ReminderPlanner.plan(
    settings: settings,
    facts: facts,
    now: now,
    location: paris,
  );

  group('training reminder', () {
    test('fires on each chosen weekday at the chosen local time', () {
      final occurrences = plan(training, at(11, 16, 10));
      expect(occurrences.take(4).map((o) => o.at), [
        at(11, 16, 18), // Mon
        at(11, 18, 18), // Wed
        at(11, 20, 18), // Fri
        at(11, 23, 18), // next Mon
      ]);
      expect(occurrences.first.at, DateTime.utc(2026, 11, 16, 17));
      expect(occurrences.every((o) => o.kind == ReminderKind.training), isTrue);
    });

    test('the next one is next week once the time has passed', () {
      expect(plan(training, at(11, 16, 19)).first.at, at(11, 18, 18));
      // Exactly at the time: already gone.
      expect(plan(training, at(11, 16, 18)).first.at, at(11, 18, 18));
      // Saturday: the next one is Monday.
      expect(plan(training, at(11, 21, 9)).first.at, at(11, 23, 18));
    });

    test('follows the chosen days and time', () {
      const settings = ReminderSettings(
        trainingEnabled: true,
        trainingDays: [2, 7],
        trainingMinutes: 7 * 60 + 30,
      );
      expect(plan(settings, at(11, 16, 10)).take(3).map((o) => o.at), [
        at(11, 17, 7, 30), // Tue
        at(11, 22, 7, 30), // Sun
        at(11, 24, 7, 30), // Tue
      ]);
    });

    test('is planned eight weeks ahead', () {
      expect(plan(training, at(11, 16, 10)), hasLength(24));
      const daily = ReminderSettings(
        trainingEnabled: true,
        trainingDays: [1, 2, 3, 4, 5, 6, 7],
      );
      expect(plan(daily, at(11, 16, 10)), hasLength(56));
    });

    test('is skipped today when a workout already ended today', () {
      final occurrences = plan(
        training,
        at(11, 16, 10),
        facts: ReminderFacts(lastWorkoutEndedAt: at(11, 16, 8)),
      );
      expect(occurrences.first.at, at(11, 18, 18));
    });

    test('"today" is the local day of the workout end', () {
      // 00:30 on Monday in Paris is still Sunday in UTC.
      final mondayNight = plan(
        training,
        at(11, 16, 10),
        facts: ReminderFacts(lastWorkoutEndedAt: at(11, 16, 0, 30)),
      );
      expect(mondayNight.first.at, at(11, 18, 18));
      // Sunday 23:30: Monday's reminder still fires.
      final sundayNight = plan(
        training,
        at(11, 16, 10),
        facts: ReminderFacts(lastWorkoutEndedAt: at(11, 15, 23, 30)),
      );
      expect(sundayNight.first.at, at(11, 16, 18));
    });

    test('is skipped today while a workout is in progress', () {
      final occurrences = plan(
        training,
        at(11, 16, 17, 30),
        facts: const ReminderFacts(workoutInProgress: true),
      );
      expect(occurrences.first.at, at(11, 18, 18));
      expect(occurrences, hasLength(23));
    });

    test('keeps local time across daylight-saving changes', () {
      const daily = ReminderSettings(
        trainingEnabled: true,
        trainingDays: [1, 2, 3, 4, 5, 6, 7],
      );
      // Clocks go back on Sunday 25 October 2026 in Paris.
      final autumn = plan(daily, DateTime.utc(2026, 10, 23, 12));
      expect(autumn[0].at, DateTime.utc(2026, 10, 23, 16)); // 18:00 CEST
      expect(autumn[1].at, DateTime.utc(2026, 10, 24, 16)); // 18:00 CEST
      expect(autumn[2].at, DateTime.utc(2026, 10, 25, 17)); // 18:00 CET
      // Clocks go forward on Sunday 28 March 2027.
      final spring = plan(daily, DateTime.utc(2027, 3, 27, 12));
      expect(spring[0].at, DateTime.utc(2027, 3, 27, 17)); // 18:00 CET
      expect(spring[1].at, DateTime.utc(2027, 3, 28, 16)); // 18:00 CEST
    });

    test('a time that does not exist that day moves forward by the gap', () {
      // 02:30 on 28 March 2027 doesn't exist in Paris: 03:30 CEST.
      expect(
        ReminderPlanner.instantOf(DateTime.utc(2027, 3, 28), 150, paris),
        DateTime.utc(2027, 3, 28, 1, 30),
      );
    });

    test('nothing when it is off', () {
      expect(plan(const ReminderSettings(), at(11, 16, 10)), isEmpty);
    });
  });

  group('weigh-in reminder', () {
    test('with no entry yet: every day from today', () {
      final occurrences = plan(weighIn, at(11, 16, 7));
      expect(occurrences.take(3).map((o) => o.at), [
        at(11, 16, 8),
        at(11, 17, 8),
        at(11, 18, 8),
      ]);
      expect(occurrences.first.daysSinceWeighIn, isNull);
      expect(occurrences, hasLength(ReminderPlanner.horizonDays));
    });

    test('stays quiet until N days have passed since the last entry', () {
      // Last weigh-in on Tuesday 10 November, N = 14 → due on the 24th.
      final occurrences = plan(
        weighIn,
        at(11, 16, 7),
        facts: ReminderFacts(lastWeighInAt: at(11, 10, 20)),
      );
      expect(occurrences.first.at, at(11, 24, 8));
      expect(occurrences.first.daysSinceWeighIn, 14);
    });

    test('N days counts calendar days, not 24-hour periods', () {
      const daily = ReminderSettings(weighInEnabled: true, weighInAfterDays: 1);
      // Weighed yesterday evening: due this morning.
      final occurrences = plan(
        daily,
        at(11, 16, 7),
        facts: ReminderFacts(lastWeighInAt: at(11, 15, 22)),
      );
      expect(occurrences.first.at, at(11, 16, 8));
      expect(occurrences.first.daysSinceWeighIn, 1);
    });

    test('repeats every day at the time until a weight is logged', () {
      final overdue = plan(
        weighIn,
        at(11, 16, 7),
        facts: ReminderFacts(lastWeighInAt: at(10, 27, 8)),
      );
      expect(overdue.take(3).map((o) => (o.at, o.daysSinceWeighIn)), [
        (at(11, 16, 8), 20),
        (at(11, 17, 8), 21),
        (at(11, 18, 8), 22),
      ]);
      expect(overdue, hasLength(ReminderPlanner.horizonDays));
    });

    test('a weight logged today: nothing today, then N days later', () {
      final occurrences = plan(
        weighIn,
        at(11, 16, 9),
        facts: ReminderFacts(lastWeighInAt: at(11, 16, 8, 30)),
      );
      expect(occurrences.first.at, at(11, 30, 8));
      expect(occurrences.first.daysSinceWeighIn, 14);
      // Logged before the reminder time: today's is gone too.
      final early = plan(
        weighIn,
        at(11, 16, 7),
        facts: ReminderFacts(lastWeighInAt: at(11, 16, 6, 45)),
      );
      expect(early.first.at, at(11, 30, 8));
    });

    test('today once the time has passed is tomorrow', () {
      expect(plan(weighIn, at(11, 16, 9)).first.at, at(11, 17, 8));
    });

    test('keeps local time across daylight-saving changes', () {
      final occurrences = plan(weighIn, DateTime.utc(2026, 10, 24, 12));
      expect(occurrences[0].at, DateTime.utc(2026, 10, 25, 7)); // 08:00 CET
      final before = plan(weighIn, DateTime.utc(2026, 10, 23, 12));
      expect(before[0].at, DateTime.utc(2026, 10, 24, 6)); // 08:00 CEST
    });
  });

  group('plan', () {
    test('merges both reminders in time order with distinct ids', () {
      const both = ReminderSettings(
        trainingEnabled: true,
        weighInEnabled: true,
      );
      final occurrences = plan(both, at(11, 16, 7));
      expect(occurrences.first.kind, ReminderKind.weighIn);
      expect(occurrences[1].kind, ReminderKind.training);
      final times = [for (final o in occurrences) o.at];
      expect(times, [...times]..sort());
      final ids = {for (final o in occurrences) o.id};
      expect(ids, hasLength(occurrences.length));
      expect(
        ids.every((id) => id >= LocalReminderScheduler.minId && id < 1 << 31),
        isTrue,
      );
    });

    test('ids depend on the kind and the day only', () {
      final a = plan(training, at(11, 16, 10)).first;
      final b = plan(
        const ReminderSettings(trainingEnabled: true, trainingMinutes: 1200),
        at(11, 16, 12),
      ).first;
      expect(a.id, b.id);
      expect(a.id, 120261116);
      expect(plan(weighIn, at(11, 16, 7)).first.id, 220261116);
    });
  });

  group('settings', () {
    test('both reminders are off by default', () {
      final settings = AppSettings.fromMap(const {}).reminders;
      expect(settings, const ReminderSettings());
      expect(settings.trainingEnabled, isFalse);
      expect(settings.weighInEnabled, isFalse);
      expect(settings.trainingDays, [1, 3, 5]);
      expect(settings.trainingMinutes, 18 * 60);
      expect(settings.weighInAfterDays, 14);
      expect(settings.weighInMinutes, 8 * 60);
    });

    test('reads the stored rows and keeps values in range', () {
      final settings = AppSettings.fromMap(const {
        SettingKeys.trainingReminder: 'true',
        SettingKeys.trainingReminderDays: '7, 2,2,9,x',
        SettingKeys.trainingReminderTime: '1800',
        SettingKeys.weighInReminder: 'true',
        SettingKeys.weighInAfterDays: '90',
        SettingKeys.weighInReminderTime: '-5',
      }).reminders;
      expect(settings.trainingEnabled, isTrue);
      expect(settings.trainingDays, [2, 7]);
      expect(settings.trainingMinutes, 1439);
      expect(settings.weighInAfterDays, 60);
      expect(settings.weighInMinutes, 0);
      expect(ReminderSettings.parseDays(''), [1, 3, 5]);
    });
  });

  group('notification texts', () {
    ReminderOccurrence occurrence(ReminderKind kind, {int? days}) =>
        ReminderOccurrence(
          kind: kind,
          day: DateTime.utc(2026, 11, 16),
          at: DateTime.utc(2026, 11, 16, 17),
          daysSinceWeighIn: days,
        );

    test('the training reminder names the next session', () {
      final n = ReminderRuntime.notificationOf(
        occurrence(ReminderKind.training),
        const ReminderFacts(nextSessionName: 'Push A'),
      );
      expect(n.title, 'Time for Push A');
      expect(n.body, Strings.reminderTrainingBody);
      expect(n.payload, 'training@2026-11-16T17:00:00.000Z');
      expect(ReminderRuntime.kindOfPayload(n.payload), ReminderKind.training);
    });

    test('an empty program gets a generic text', () {
      final n = ReminderRuntime.notificationOf(
        occurrence(ReminderKind.training),
        const ReminderFacts(),
      );
      expect(n.title, Strings.reminderTrainTitle);
      expect(n.body, Strings.reminderTrainBody);
    });

    test('the weigh-in reminder says how long since the last one', () {
      final n = ReminderRuntime.notificationOf(
        occurrence(ReminderKind.weighIn, days: 15),
        const ReminderFacts(),
      );
      expect(n.title, 'Time to weigh in');
      expect(n.body, 'Your last weigh-in was 15 days ago.');
      expect(ReminderRuntime.kindOfPayload(n.payload), ReminderKind.weighIn);
      expect(
        ReminderRuntime.notificationOf(
          occurrence(ReminderKind.weighIn),
          const ReminderFacts(),
        ).body,
        Strings.reminderFirstWeighInBody,
      );
      expect(ReminderRuntime.kindOfPayload('nonsense'), isNull);
    });
  });
}
