/// Every user-facing string of the app, in one place. English only.
abstract final class Strings {
  static const String appName = 'My Bodybuilding Program';

  static const String startupError = "The app couldn't open its database.";

  // Tabs
  static const String tabToday = 'Today';
  static const String tabProgram = 'Program';
  static const String tabProgress = 'Progress';
  static const String tabProfile = 'Profile';

  // Today
  static const String todayWelcomeTitle = 'Welcome!';
  static const String todayWelcomeBody =
      'Your program is a loop of sessions, like Push → Pull → Legs. '
      "Create the first one and this screen will always tell you what's next.";
  static const String todayCreateFirstSession = 'Create your first session';

  // Program
  static const String programEmptyTitle = 'No sessions yet';
  static const String programEmptyBody =
      'Add the sessions of your loop here. The app will always know which '
      'one comes next.';

  // Progress
  static const String progressEmptyTitle = 'Nothing to show yet';
  static const String progressEmptyBody =
      'Your calendar, charts and records appear here after your first '
      'workout.';

  // Profile
  static const String profileEmptyTitle = 'No stats yet';
  static const String profileEmptyBody =
      'Bodyweight and training stats appear here once you start logging.';
}
