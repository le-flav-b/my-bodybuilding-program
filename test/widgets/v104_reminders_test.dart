import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/core/notifications/reminder_scheduler.dart';
import 'package:my_bodybuilding_program/features/profile/data/body_weight_repository.dart';
import 'package:my_bodybuilding_program/features/profile/presentation/profile_screen.dart';
import 'package:my_bodybuilding_program/features/settings/data/settings_repository.dart';
import 'package:my_bodybuilding_program/features/settings/domain/reminders.dart';
import 'package:my_bodybuilding_program/features/today/presentation/today_screen.dart';
import 'package:my_bodybuilding_program/features/workout/data/workout_repository.dart';

import '../helpers/demo_data.dart';
import '../helpers/test_app.dart';
import '../helpers/test_env.dart';
import '../helpers/workout_data.dart';

void main() {
  late TestApp app;
  late WorkoutData data;

  /// Monday 16 November 2026, 10:00 (the fake time zone is UTC).
  final monday = DateTime.utc(2026, 11, 16, 10);

  Future<void> start(
    WidgetTester tester, {
    bool program = true,
    String? launchPayload,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    app = TestApp(clock: FakeClock(monday));
    app.reminders.launchPayload = launchPayload;
    final demo = DemoData(app.container);
    data = WorkoutData(app, demo);
    await app.pump(tester);
    if (program) {
      await tester.runAsync(demo.create);
      await app.settle(tester);
    }
  }

  Future<T> db<T>(WidgetTester tester, Future<T> Function() f) async {
    final result = (await tester.runAsync(f)) as T;
    await app.settle(tester);
    return result;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await app.settle(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    app.container.read(routerProvider).push(Routes.settings).ignore();
    await app.settle(tester);
    await tester.ensureVisible(find.text(Strings.weighInReminder));
    await app.settle(tester);
  }

  Future<ReminderSettings> stored(WidgetTester tester) => db(
    tester,
    () async =>
        (await app.container.read(settingsRepositoryProvider).getSettings())
            .reminders,
  );

  List<ReminderNotification> scheduled(ReminderKind kind) => [
    for (final n in app.reminders.scheduled)
      if (n.payload.startsWith('${kind.name}@')) n,
  ];

  Finder switchOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );

  bool isOn(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(switchOf(title)).value;

  testWidgets('both reminders are off by default; nothing is scheduled', (
    tester,
  ) async {
    await start(tester);
    await openSettings(tester);
    expect(find.text(Strings.remindersSection), findsOneWidget);
    expect(isOn(tester, Strings.trainingReminder), isFalse);
    expect(isOn(tester, Strings.weighInReminder), isFalse);
    expect(find.text(Strings.reminderOff), findsNWidgets(2));
    expect(find.bySemanticsLabel('Monday'), findsNothing);
    expect(find.text(Strings.remindAfter), findsNothing);
    expect(app.reminders.scheduled, isEmpty);
    expect(app.reminders.permissionRequests, 0);
    // Planned once at launch, scheduling everything again (alarms are lost
    // when the app is force-stopped).
    expect(app.reminders.applyCount, 1);
    expect(app.reminders.lastRescheduleAll, isTrue);
  });

  testWidgets('training reminder: on, days, schedule with the next session', (
    tester,
  ) async {
    await start(tester);
    await openSettings(tester);
    await tapAndSettle(tester, find.text(Strings.trainingReminder));

    expect(app.reminders.permissionRequests, 1);
    expect(isOn(tester, Strings.trainingReminder), isTrue);
    expect((await stored(tester)).trainingEnabled, isTrue);
    expect(find.text('Mon, Wed, Fri · 18:00'), findsOneWidget);
    expect(find.text(Strings.reminderTime), findsOneWidget);

    var training = scheduled(ReminderKind.training);
    expect(training.first.title, 'Time for Push A');
    expect(training.first.at, DateTime.utc(2026, 11, 16, 18));
    expect(training, hasLength(24));
    expect(app.reminders.lastRescheduleAll, isFalse);

    // Tuesday on, Monday off.
    await tapAndSettle(tester, find.bySemanticsLabel('Tuesday'));
    await tapAndSettle(tester, find.bySemanticsLabel('Monday'));
    expect((await stored(tester)).trainingDays, [2, 3, 5]);
    expect(find.text('Tue, Wed, Fri · 18:00'), findsOneWidget);
    training = scheduled(ReminderKind.training);
    expect(training.first.at, DateTime.utc(2026, 11, 17, 18));

    // The last day can't be turned off.
    await tapAndSettle(tester, find.bySemanticsLabel('Tuesday'));
    await tapAndSettle(tester, find.bySemanticsLabel('Wednesday'));
    await tapAndSettle(tester, find.bySemanticsLabel('Friday'));
    expect((await stored(tester)).trainingDays, [5]);

    // Off again: nothing scheduled.
    await tapAndSettle(tester, find.text(Strings.trainingReminder));
    expect(isOn(tester, Strings.trainingReminder), isFalse);
    expect(app.reminders.scheduled, isEmpty);
  });

  testWidgets('the time picker sets the reminder time', (tester) async {
    await start(tester);
    await openSettings(tester);
    await tapAndSettle(tester, find.text(Strings.trainingReminder));
    await tapAndSettle(tester, find.text(Strings.reminderTime));
    await tapAndSettle(tester, find.byTooltip('Switch to text input mode'));
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.first, '7');
    await tester.enterText(fields.last, '45');
    await tester.pump();
    await tapAndSettle(tester, find.text('OK'));
    expect((await stored(tester)).trainingMinutes, 7 * 60 + 45);
    expect(find.text('Mon, Wed, Fri · 07:45'), findsOneWidget);
    expect(
      scheduled(ReminderKind.training).first.at,
      DateTime.utc(2026, 11, 18, 7, 45),
    );
  });

  testWidgets(
    'permission refused: the switch stays off and a dialog explains',
    (tester) async {
      await start(tester);
      app.reminders.grantPermission = false;
      await openSettings(tester);
      await tapAndSettle(tester, find.text(Strings.weighInReminder));
      expect(find.text(Strings.notificationsOffTitle), findsOneWidget);
      expect(find.text(Strings.notificationsOffBody), findsOneWidget);
      await tapAndSettle(tester, find.text(Strings.ok));
      expect(find.text(Strings.notificationsOffTitle), findsNothing);
      expect(isOn(tester, Strings.weighInReminder), isFalse);
      expect((await stored(tester)).weighInEnabled, isFalse);
      expect(app.reminders.scheduled, isEmpty);
    },
  );

  testWidgets('weigh-in reminder: N days, and a logged weight re-plans it', (
    tester,
  ) async {
    await start(tester);
    await openSettings(tester);
    await tapAndSettle(tester, find.text(Strings.weighInReminder));
    expect(find.text('After 14 days · 08:00'), findsOneWidget);
    // No weigh-in yet: every day from tomorrow 08:00 (today's is gone).
    var weighIns = scheduled(ReminderKind.weighIn);
    expect(weighIns.first.at, DateTime.utc(2026, 11, 17, 8));
    expect(weighIns.first.title, Strings.reminderWeighInTitle);
    expect(weighIns.first.body, Strings.reminderFirstWeighInBody);

    await tapAndSettle(tester, find.text(Strings.remindAfter));
    await tapAndSettle(tester, find.widgetWithText(ActionChip, '7'));
    await tapAndSettle(tester, find.text(Strings.ok));
    expect((await stored(tester)).weighInAfterDays, 7);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('After 7 days · 08:00'), findsOneWidget);

    // Logging a weight moves the next reminder 7 days later.
    await db(
      tester,
      () => app.container
          .read(bodyWeightRepositoryProvider)
          .addEntry(measuredAt: monday, weightKg: 80),
    );
    weighIns = scheduled(ReminderKind.weighIn);
    expect(weighIns.first.at, DateTime.utc(2026, 11, 23, 8));
    expect(weighIns.first.body, 'Your last weigh-in was 7 days ago.');
  });

  testWidgets('a workout in progress or finished today skips today', (
    tester,
  ) async {
    await start(tester);
    await openSettings(tester);
    await tapAndSettle(tester, find.text(Strings.trainingReminder));
    expect(
      scheduled(ReminderKind.training).first.at,
      DateTime.utc(2026, 11, 16, 18),
    );

    final id = await db(tester, data.startPush);
    expect(
      scheduled(ReminderKind.training).first.at,
      DateTime.utc(2026, 11, 18, 18),
    );

    await db(tester, () => data.logFirstSets(id, 2));
    await db(
      tester,
      () => app.container.read(workoutRepositoryProvider).finish(id),
    );
    // Done today, and the program moved on to Legs.
    final training = scheduled(ReminderKind.training);
    expect(training.first.at, DateTime.utc(2026, 11, 18, 18));
    expect(training.first.title, 'Time for Legs');
  });

  testWidgets('an empty program gets the generic text', (tester) async {
    await start(tester, program: false);
    await openSettings(tester);
    await tapAndSettle(tester, find.text(Strings.trainingReminder));
    expect(
      scheduled(ReminderKind.training).first.title,
      Strings.reminderTrainTitle,
    );
  });

  testWidgets('tapping a reminder opens Today or the log-weight dialog', (
    tester,
  ) async {
    await start(tester);
    await openSettings(tester);

    app.reminders.tap('weighIn@2026-11-17T08:00:00.000Z');
    await app.settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text(Strings.logWeight), findsWidgets);
    expect(find.byType(Dialog), findsOneWidget);
    await tapAndSettle(tester, find.text(Strings.cancel));
    expect(find.byType(Dialog), findsNothing);

    app.reminders.tap('training@2026-11-16T18:00:00.000Z');
    await app.settle(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('a weigh-in reminder that launched the app opens the dialog', (
    tester,
  ) async {
    await start(tester, launchPayload: 'weighIn@2026-11-16T08:00:00.000Z');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });
}
