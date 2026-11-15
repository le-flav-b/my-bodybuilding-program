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
  static const String todayComingTitle = 'Your program is ready';
  static const String todayComingBody =
      'Starting a workout from here arrives with the next update.';

  // Progress
  static const String progressEmptyTitle = 'Nothing to show yet';
  static const String progressEmptyBody =
      'Your calendar, charts and records appear here after your first '
      'workout.';

  // Profile
  static const String profileEmptyTitle = 'No stats yet';
  static const String profileEmptyBody =
      'Bodyweight and training stats appear here once you start logging.';

  // Common
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String archive = 'Archive';
  static const String restore = 'Restore';
  static const String add = 'Add';
  static const String undo = 'Undo';
  static const String done = 'Done';
  static const String ok = 'OK';
  static const String back = 'Back';
  static const String close = 'Close';
  static const String edit = 'Edit';
  static const String more = 'More';
  static const String reps = 'Reps';
  static const String time = 'Time';
  static const String load = 'Load';
  static const String unit = 'Unit';
  static const String max = 'max';
  static const String bodyweight = 'Body';

  static String exerciseCount(int n) => n == 1 ? '1 exercise' : '$n exercises';
  static String setCount(int n) => n == 1 ? '1 set' : '$n sets';
  static String approxMinutes(int minutes) => '~$minutes min';
  static String rest(String clock) => 'rest $clock';
  static String restChip(String clock) => 'Rest $clock';

  // Program tab
  static const String programExercises = 'Exercises';
  static String programCatalogueCount(int n) => '$n in the catalogue';
  static String programLoop(int n) => 'Sessions · loop of $n';
  static const String programDragToReorder = 'Drag to reorder';
  static String programLoopNote(String last, String first) =>
      'After $last, back to $first';
  static const String programAddSession = 'Add session';
  static const String programNext = 'Next';
  static const String programStartSession = 'Start this session';
  static const String programNoSessionsTitle = 'No sessions yet';
  static const String programNoSessionsBody =
      'Your program is a loop of sessions. Create the first one and Today '
      "will tell you what's next.";
  static const String newSessionTitle = 'New session';
  static const String sessionNameLabel = 'Session name';
  static const String sessionNameHint = 'e.g. Push A';
  static const String create = 'Create';

  // Session editor
  static const String editSession = 'Edit session';
  static const String deleteSession = 'Delete session';
  static String deleteSessionTitle(String name) => 'Delete "$name"?';
  static const String deleteSessionBody =
      'The session leaves your program. Past workouts done from it stay in '
      'your history.';
  static const String addExercise = 'Add exercise';
  static const String addSet = 'Add set';
  static const String removeSet = 'Remove set';
  static const String removeExercise = 'Remove exercise';
  static const String expand = 'Show sets';
  static const String collapse = 'Hide sets';
  static const String reorder = 'Reorder';
  static const String sessionEmptyTitle = 'No exercises yet';
  static const String sessionEmptyBody =
      'Add the exercises of this session, then set their sets and rest.';
  static const String setNumber = '#';
  static const String restTime = 'Rest time';
  static const String restBetweenSets = 'Rest between sets';
  static const String targetReps = 'Target reps';
  static const String targetTime = 'Target time';
  static const String toMax = 'To the max';
  static const String toMaxHint = 'As many as possible, no fixed target';
  static const String loadDialogTitle = 'Load';
  static const String loadNoneHint =
      'Leave empty for bodyweight. A negative '
      'value means assisted.';
  static const String noLoad = 'No load';
  static const String seconds = 'seconds';
  static const String minutes = 'min';
  static const String manageUnits = 'Manage units';
  static String unitStep(String step) => 'step $step';

  // Catalogue
  static const String exercisesTitle = 'Exercises';
  static String searchExercises(int n) => 'Search $n exercises';
  static const String searchExercisesShort = 'Search exercises';
  static const String archived = 'Archived';
  static const String newExercise = 'New exercise';
  static const String newShort = 'New';
  static String noExerciseMatches(String query) =>
      'No exercise matches "$query"';
  static const String noExercises = 'No exercises here';
  static const String noArchivedExercises = 'No archived exercises';
  static const String noArchivedExercisesBody =
      'Exercises you archive are kept here, with their history.';
  static const String noExercisesBody =
      'Try another search or filter, or create your own exercise.';
  static String createNamed(String name) => 'Create "$name"';
  static const String swapExercise = 'Swap exercise';
  static String swapReplacing(String name) =>
      'Replacing $name. Sets already logged stay on it.';

  // Exercise detail / edit
  static const String exerciseNotFound = 'This exercise no longer exists.';
  static const String myNotes = 'My notes / setup';
  static const String myNotesHint = 'e.g. seat 4, pin 7';
  static const String myNotesEmpty = 'Add your setup: seat, pin, grip…';
  static const String editNotes = 'Edit my notes';
  static const String editExercise = 'Edit exercise';
  static const String archivedBanner =
      'Archived: hidden from the list and pickers, kept in history.';
  static const String exerciseName = 'Name';
  static const String exerciseDescription = 'Description / form cues';
  static const String exerciseDescriptionHint =
      'Pulleys high, step forward, hug a tree…';
  static const String measure = 'Measure';
  static const String measureLocked =
      "Used in a session or in your history, so the measure can't change.";
  static const String musclesPickLabel =
      'Muscles · tap once = primary, twice = secondary';
  static const String camera = 'Camera';
  static const String gallery = 'Gallery';
  static const String removePhoto = 'Remove photo';
  static const String noPhoto = 'No photo: the muscle placeholder is shown';
  static const String photoFailed = "The photo couldn't be loaded.";
  static const String nameRequired = 'Give the exercise a name.';
  static const String neverUsedCanDelete = 'Never used, so it can be deleted.';
  static const String hasHistoryCanArchive =
      'It has history, so it can only be archived.';
  static const String isArchivedCanRestore = 'Archived. Restore it to use it.';
  static String deleteExerciseTitle(String name) => 'Delete "$name"?';
  static const String deleteExerciseBody =
      'It was never done, so it can be deleted for good. It is also removed '
      'from the sessions that plan it.';
  static String archiveExerciseTitle(String name) => 'Archive "$name"?';
  static const String archiveExerciseBody =
      "It has history, so it can't be deleted. It will be hidden from the "
      'catalogue and pickers, and stay in your history and charts. You can '
      'restore it any time.';
  static const String discardChangesTitle = 'Discard changes?';
  static const String discardChangesBody = "Your edits won't be saved.";
  static const String discard = 'Discard';
  static const String keepEditing = 'Keep editing';

  // Settings
  static const String settings = 'Settings';
  static const String appearance = 'Appearance';
  static const String theme = 'Theme';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String library = 'Library';
  static const String loadUnits = 'Load units';
  static const String muscles = 'Muscles';
  static const String musclesSubtitle = 'Used to tag and filter exercises';
  static String muscleCount(int n) => n == 1 ? '1 muscle' : '$n muscles';

  // Load units
  static const String unitsNeverConverted =
      'Loads are never converted between units.';
  static const String addUnit = 'Add unit';
  static const String newUnit = 'New unit';
  static const String editUnit = 'Edit unit';
  static const String unitName = 'Name';
  static const String unitNameHelper = 'Shown after the value, e.g. "5 level"';
  static const String unitStepLabel = 'Step';
  static const String unitDecimals = 'Decimals';
  static String unitPreview(String text) => 'Preview: $text';
  static String unitBuiltIn(String step, String decimals) =>
      'Built in · step $step · $decimals';
  static String unitSummary(String step, String decimals, String usage) =>
      'Step $step · $decimals · $usage';
  static String decimals(int n) => n == 1 ? '1 decimal' : '$n decimals';
  static String usedInExercises(int n) =>
      n == 0 ? 'not used yet' : 'used in ${exerciseCount(n)}';
  static const String unitInUse = 'This unit is in use; archive it instead.';

  // Muscles
  static const String addMuscle = 'Add muscle';
  static const String newMuscle = 'New muscle';
  static const String renameMuscle = 'Rename muscle';
  static const String muscleName = 'Name';
  static const String hidden = 'Hidden';
  static const String hide = 'Hide';
  static const String show = 'Show';
  static const String hiddenFromFilters = 'Hidden from filters and pickers';
}
