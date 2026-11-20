# Handoff: My Bodybuilding Program

This file passes context from one Claude session to the next. Each session reads it first and updates it before finishing.

## Project

An Android app (Flutter) to plan my training, guide me through each workout, and track my progress. A first attempt was dropped; we're starting over. `legacy/` is reference material only, not a spec.

## Session plan

1. **Specifications**: done.
2. **Design**: done (see "Design session outcome" below).
3. **Catalogue seed** (data task, separate): done (`assets/seed/`, `tools/seed/`).
4. **App**: milestones M0–M6 (v1.0) done, then the 1.0.x line (v1.0.1 fixes, v1.0.2 icon, v1.0.4 reminders); the later items next, one branch + PR each, following `CLAUDE.md`, Notion and `design/` (never Figma). See "App session: current state / next step" at the end.

A "master" session coordinates the work and the move from one session to the next.

## Where things are

- **Notion (master spec):** https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30
  - **Features**: one toggle per feature (MVP / Later / Dropped)
  - **Screens & Navigation**: navigation diagram + one toggle per screen, with the mapping from the old Figma
  - **Data & Sync**: the four data layers, tables, seed rules, images, derived data, cloud sync (after v1.0)
  - **Technical**: stack, architecture, seed file format, testing, decisions log
  - **Development** database: specs, design, data task, M0–M6, later items; sorted by version, so the first row not Done is the next step
- **Figma:** https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program (file key `ut2qBne1bdpEzGoDeNldNK`)
- **`design/`** (after the design session): tokens, previews, screenshots and screen specs. This is what coding sessions read, not Figma.
- **`CLAUDE.md`**: rules for coding sessions. **`README.md`**: summary and links.

## Key decisions (details in Notion)

- **Basics:** English only, single user, Android/Flutter, offline-first. No account in v1; Firebase backup with optional Google sign-in comes right after v1.0 (data is sync-ready from day one).
- **Catalogue:** a flat exercise catalogue (name, description, image, reps-or-time measure, muscles) with **no variants, no equipment, no movement patterns**. I can add exercises in the app, with a photo. Exercises are editable; an exercise with history can only be archived. The muscle list ships pre-filled and is editable.
- **Personal exercise notes** (setup, e.g. "seat 4, pin 7") are kept separate from the catalogue.
- **Load units** are a user-managed list (kg built in, plus custom units such as "level" with a step and decimals). The unit is chosen per planned set and logged per set, never converted.
- **Program:** one program = an ordered loop of sessions with a "next session" pointer that follows what I actually did. Skip is possible, there are no rest days in the loop, and the program starts empty.
- **Sessions:** a flat list of exercises (no blocks), each with **per-set targets**: reps or time as a number or "max", optional load + unit. Rest time is set per exercise.
- **Workout:**
  - Guided player plus a list view, with jump, reorder, skip and swap.
  - Changes apply to this workout only; at the end the app asks "Update the program?".
  - The player shows last time's sets, my notes, the next exercise and session progress.
  - Timed sets have a 3-2-1 lead-in.
  - Rest timer with notifications that work when the phone is locked.
  - Crash-safe, with a resume prompt.
- **Progress:**
  - Per-exercise timeline chart, with each unit on its own scale/colour on the same chart.
  - Training **bests** per unit (computed): heaviest load, most reps, longest hold. Called "PRs" until v1.0.1.
  - **Personal records (PRs)**, since v1.0.1: attempts made on purpose, logged by hand in their own table (`personal_records`), never mixed with training sets.
  - Calendar, plus a weekly streak (≥ N workouts per week, default 3).
- **Navigation:** 4 tabs, Today · Program · Progress · Profile. Settings opens from Profile. The exercise catalogue lives inside Program.
- **Profile:** bodyweight log + chart, stats (totals, streaks, this month vs last) and the latest 5 PRs.
- **Later (after v1.0):** reminders (v1.0.4, done: moved before sync), cloud sync (1.1), progress photos (1.2: pose tags, private, linked bodyweight), then supersets, media controls and export. The 1.0.x line stays open for fixes and small changes.
- **Dropped:** music, random session, ~~manual max load~~ (back in v1.0.1 as personal records), fixed weekly split, progression suggestions, variants, equipment, movement patterns, favourites/hidden, warm-up and failure flags, blocks, phases, several programs.

## Brief for the DESIGN session

Goal: the design for this spec, approved by me screen by screen, saved in the repo (`design/`) and written to Figma once approved.

### Figma Starter plan: hard limits
- **3 pages per file.**
- **Very few Figma read calls per month** (about 6–20). `get_screenshot`, `get_design_context`, `get_metadata`, `search_design_system` and `whoami` all count, and the master session has already used about 3.
- **Write calls (`use_figma`) appear to be exempt.** Do all Figma work through `use_figma`: it runs plugin JavaScript, so it can also *return* information (node names, IDs, sizes) for checking. Load the `figma-use` skill first, as the Figma server requires.
- **Never call a Figma read tool.** If a Figma call fails with a rate-limit error, stop using Figma and tell me; don't retry in a loop.
- The Figma session ID is not saved between sessions; call `create_session` once at the start.

### Workflow
1. **Preview first, outside Figma.** Build the design as HTML/CSS in `design/preview/`, sized like a phone (412×915 dp, Material 3). Render screenshots with the preinstalled Playwright (deviceScaleFactor 2) and send them to me with `SendUserFile`. Iterate until I say a screen is approved. Go in this order, getting my approval at each step:
   1. **Foundations**: colours, type, spacing, radius, light + dark
   2. **Components**
   3. **Screens**: one feature at a time
2. **Save the approved design in the repo** (this is what the app sessions read; they never read Figma):
   - `design/tokens.json`: colours (light/dark), type scale, spacing, radius. Named so the Flutter theme maps it 1:1.
   - `design/preview/`: the HTML source, with an `index.html` linking every screen and clickable prototype links for the flows in step 7 below.
   - `design/screens/*.png`: final screenshots, light and dark, named `<screen>_<state>_<theme>.png`.
   - `design/README.md`: for each screen, the components used, layout and sizes, states, and interactions; for each component, its variants.
3. **Only then, write to Figma** with `use_figma`, in large batches. Use 3 pages:
   1. `Archive (legacy FR)`: rename "Page 1"; don't modify the old design.
   2. `Foundations & Components`: Figma variables from `tokens.json` (colour modes light/dark, spacing, radius) and the components.
   3. `Screens & Prototype`: every approved screen, light and dark, with prototype links for the flows in step 7 below.

   If Figma becomes unusable, the repo's `design/` folder is enough to continue. Just tell me.

### Content (unchanged from the spec)
1. **Foundations** (Material 3, light + dark):
   - Colours from `legacy/some_previous_app_assets/values/colors.xml`: coral `#F55E42` (primary), light coral `#F68974`, yellow `#FFC854` (accent, PR/trophy), dark grey `#181B1E`, grey `#2D3135`, off-white `#EEEEEE`, white `#FCFCFC`. Check contrast (WCAG AA), especially white text on coral.
   - Fonts: Kameron Bold for the logo only, Inter for everything else (both in `legacy/some_fonts/`).
2. **Components:**
   - bottom nav (4 tabs), session card, exercise row (image, name, planned sets)
   - set row: target, last time, steppers, unit selector, done
   - rest timer: circular countdown, ±15 s, skip; timed-set timer with 3-2-1
   - multi-unit chart (one colour/scale per unit), PR trophy overlay, calendar month, streak chip
   - stat tiles, empty states, dialogs, bottom-sheet exercise picker, filter chips, unit editor
3. **Screens:** every screen listed in Notion > Screens & Navigation (toggles describe content and states), in light and dark, all text in English. Include the states:
   - Today: normal / in progress / empty program
   - Player: rep-based / time-based / resting
   - Settings (no cloud section in v1; design the signed out / signed in states as a later extra)
4. **Images:**
   - Exercise illustrations in `legacy/some_images/` show the visual style to keep for catalogue images.
   - Exercises without an image get a placeholder by primary muscle; the old `abdominals`, `back_biceps`, `legs` and `pectorals_triceps` images can inspire it.
   - Reuse `trophy.png` for PRs and the old pillow art for empty/rest states (the pillow was removed in v1.0.1: empty states use icons).
5. **UX priorities:** one-handed use, touch targets ≥ 48 dp, one tap to log a set that matches the target, readable at arm's length, timer visible from a distance.
6. The old Figma design (Archive page) is not to be read through the API, since that costs read calls. If you need to know what it looked like, ask me for screenshots.
7. **Prototype flows:**
   - Main flow: Today → Preview → Player (log sets, rest, swap) → Summary (update-program prompt) → Today with the next session advanced.
   - Also Progress → Exercise progress, and Profile → Settings → Load units.
8. If design work reveals a gap in the spec, **update Notion first** and note it here. Set the "Design" row in the Notion Development database to In progress, then Done.

## Contents of `legacy/`

| Path | What it is |
|---|---|
| `exercises.xlsx` | Old exercise list (French): the exercises I did at the time. Input for the catalogue data task, not a spec |
| `program_draft_french.xlsx` | Old Push / Pull / Legs draft (French). Reference only; the program starts empty |
| `some_images/` | Exercise illustrations + UI icons (`_active` / `_dark_mode` variants), French file names |
| `some_fonts/` | Cantarell Bold, Inter Medium, Kameron Bold, Source Sans Pro Regular (only Kameron + Inter kept) |
| `some_previous_app_assets/` | Old Android app leftovers: `drawable*/` and `values/` (colours, themes, strings) |

## Design session outcome (2026-11-15)

**Where it is:** `design/README.md` (foundations, every component and screen spec), `design/tokens.json`, `design/screens/*.png` (32 screens × light/dark + 5 sheets), `design/preview/` (HTML source, `index.html`, clickable `prototype.html`). App sessions read only this folder.

**Decisions made while designing** (all written into Notion first):
- **Colours:** white on coral `#F55E42` fails WCAG AA, so coral is the *brand* colour only. Light-theme `primary` is `#C23E27` with white text, dark-theme `primary` is `#F68974` with dark text. Yellow is a fill only (records); the PR text colour on light is `#8A5A00`.
- **Icons:** Material Symbols Rounded → Flutter `Icons.*_rounded` (fallbacks listed in the README; no new dependency).
- **Images:** catalogue illustrations always sit on a white rounded "image well" (also in dark mode). The no-image placeholder is the old muscle-region photo for the primary muscle.
- **Pause (added at the user's request, it was missing from the spec):** pause button in the player header. It freezes the workout clock and any timer; paused time is excluded from the duration; the notification shows "Paused"; the 12 h auto-finish counts from the last action. Written in Notion > Features > Workout and Screens > Workout player. **Coding sessions: include it in M3.**
- **Timed sets:** at 0 the set is logged automatically; "Log" records a time without the timer.
- **Multi-unit chart:** legend chips show/hide units; the first two visible units own the left and right axes, others are drawn without labels; lines only join points of the same unit.
- **Smaller additions:** trophy overlay auto-closes after 4 s; the swap picker opens on the current exercise's primary muscle; Today has "Up next" (in progress) and "last workout" cards plus a pick-session sheet; the update prompt lists changes and keeps skipped exercises in the program; the summary shows the next session; Progress is 3 tabs (Calendar · Exercises · History) with search, PR badges and sparklines; the session editor expands exercise cards in place; muscle chips cycle primary → secondary → off; units/muscles show usage counts; weekly target is a − / + stepper.

**Figma (Starter plan):** the MCP call limit was reached during the write, and `use_figma` counts against it too, not only read tools. Done: 3 pages, variables (`light/*` + `dark/*` groups because Starter allows only 1 mode), text styles, core components, 64 screen frames with prototype links and flows. **Not done:** the screen/sheet images are uploaded but not attached to their frames. `design/figma.md` lists node IDs and image hashes for a 2-call fix when quota returns. Not blocking: nobody reads Figma for the app.

**Environment:** this session moved to the `my-bodybuilding-program` cloud environment and `mcp.figma.com` was added to its allowed hosts (needed for Figma image upload).

## Status

- [x] Repo started, legacy assets imported (master session)
- [x] Specifications: Notion spec (4 pages + Development database), `README.md`, `CLAUDE.md` (specs session, 2026-11-15)
- [x] Design: approved screen by screen, saved in `design/`; Figma partly mirrored (design session, 2026-11-15)
- [x] Catalogue seed (data task)
  - Seed in `assets/seed/` (`catalogue.json` v1: 13 muscles, 82 exercises, 44 WebP images); validator and how-to in `tools/seed/`.
- [ ] App (M0–M6 → v1.0)
  - [x] M0 Setup (v0.1.0)
  - [x] M1 Data layer (v0.2.0)
  - [x] M2 Catalogue & program (v0.3.0)
  - [x] M3 Workout (v0.4.0)
  - [x] M4 Progress (v0.5.0)
  - [x] M5 Profile (v0.6.0)
  - [x] M6 Release (v1.0.0)
- [x] v1.0.1 fixes (launcher label, icon, empty states, personal records, Bests)
- [x] v1.0.2 icon (the first icon's hand, chosen from proposals)
- [x] v1.0.4 Reminders (training + weigh-in) and the Program empty-state icon (`repeat`)
- [ ] Later items (1.1 Cloud sync ← *next*, 1.2 Progress photos, then supersets, media controls, export/import)

## App session: current state / next step

*Updated at the end of every milestone. A fresh session resumes from `main` plus this section.*

**Done so far:** M0–M6 (v1.0.0), the v1.0.1 fixes, the v1.0.2 icon and the v1.0.4 reminders are released.
- M0: 4-tab shell, theme from `design/tokens.json`, CI.
- M1: Drift database, repositories, seed import, all domain rules with unit tests.
- M2: catalogue (search, muscle filter, archived), exercise detail (my notes edited in place) and create/edit (photo from camera or gallery, muscles primary/secondary, Delete / Archive / Restore), exercise picker sheet (`showExercisePicker(replacing: …, initialMuscleIds: …)`), Program tab (loop, next session, drag to reorder, add session, play → preview), session editor, Settings (Appearance + Library), Load units, Muscles.
- M3: Today (normal / in progress / empty / pick-session sheet / skip with Undo), session preview (draft edits for this workout only), player (`workout_player_screen.dart` + `player_parts.dart`, `player_rest_view.dart`, `player_timed_view.dart`, `player_overlays.dart`: header with elapsed + time left, segment bar, exercise block with form cues / note / ⋮ swap-skip-change unit, setup note strip, set rows + current set card, rest view, timed sets with 3-2-1 lead-in, paused overlay, trophy overlay, all-done state, next-exercise footer), list view (`workout_list_screen.dart`), summary (`workout_summary_screen.dart`, "Update the program?" first), resume prompt once at launch (`AppShell`), notifications + beeps/vibration + keep screen on, release workflow with certificate check and GitHub release.

- M4: Progress tab (`progress_screen.dart`: Calendar with week marks, streak and month tiles; Exercises done with search, best and sparkline; History grouped by month with totals and PR badges), Exercise progress (`exercise_progress_screen.dart`: record tiles per unit, legend chips, `MultiUnitChart` on fl_chart with each series normalised by `ChartScale`, range 1M–All, all sets grouped by workout), Workout detail (`workout_detail_screen.dart`: note, edit/delete set, exercise note/remove, delete workout), links from Today's last-workout card and the exercise detail (`ExerciseProgressCard`). Pure rules added: `CalendarRule`, `ChartScale`. Shared widgets in `progress_widgets.dart` (`StatTile`, `statValue`, `Sparkline`, `RecordCountBadge`, `headlineRecord`, `longDuration`) and `streak_chip.dart`.

- M5: Profile tab (`profile/presentation/profile_screen.dart`: bodyweight card with sparkline and +, stat tiles, this month vs last, latest 5 records), Bodyweight (`bodyweight_screen.dart`: value, change over 30 days, trend chart, entries with edit/delete, Log weight; `body_weight_dialog.dart`, `logWeightFlow`), Settings complete (Workout: default rest, sound, vibration, keep screen on; Streak: weekly target 1–7; About: `AppInfo.version`, kept equal to the pubspec version by `test/app/app_info_test.dart`). `ChartRangeRow` moved to `progress_widgets.dart`.

- M6: adaptive launcher icon (brand coral background, white dumbbell; monochrome layer for themed icons; legacy PNGs) and Android 12+ splash (surface colour + icon on a coral circle; `values-v31`, `values-night-v31`, `launch_background.xml` before 12), all rendered by `flutter test tool/icon` (re-run it after changing the icon). README: release and install sections. Version `1.0.0+7`.

- v1.0.1 fixes (after v1.0.0 was installed on the phone):
  - Launcher label "My Program" (activity `android:label`; the application label and every other place keep "My Bodybuilding Program").
  - New icon: a fist (off-white) gripping a dumbbell (brand yellow) on coral, flat, parts separated by transparent gaps (`tool/icon/fist_dumbbell_painter.dart`; `flutter test tool/icon` also writes `build/icon_preview.png`). Same drawing on both splashes.
  - Empty states: no illustration any more (`EmptyState` takes an icon only; `sleep.png` deleted). Today's welcome has no "Push → Pull → Legs" example; the new-session name field has no hint.
  - **Personal records (PRs)**: table `personal_records` (personal layer, synced columns), **schema v2** (migration adds the table + index only). `PersonalRecord` / `PersonalRecordDraft` (`errorFor(measure)`, `normalizedFor`) and `PrRule` (`bests`, `currentBest`, `latest`, `compare`) in `progress/domain/personal_record.dart`; `PersonalRecordsRepository` (validates against the exercise's measure). UI: `PersonalRecordsScreen` (`/exercises/:id/records`), `PrSummaryCard` (Exercise detail + top of Exercise progress, which now also shows when the exercise has no training), `showPrDialog` + `addPrFlow` / `editPrFlow` / `deletePrFlow` / `prValueText` (`pr_flows.dart`), Profile "Latest PRs". An exercise with PRs counts as having history; a unit used by a PR counts as in use.
  - The computed records are **Bests** everywhere in the UI ("New best" overlay, "New bests" in the summary, "Bests" tiles, "Best" chips). Code renames: `Records` → `Bests`, `PersonalRecord` (computed) → `TrainingBest`, `RecordEvent` → `BestEvent`, `PrChip` → `TrophyChip`, `RecordCountBadge` → `BestCountBadge`, `headlineRecord` → `headlineBest`; `records.dart` → `bests.dart`.
  - `design/README.md` updated; new renders in `design/screens/v101_*` (from `tool/screenshots/v101_test.dart`). Version `1.0.1+8`.
- v1.0.2 icon: the owner reviewed proposals (A–R, rendered outside the repo) and chose the first app's hand, redrawn flat and white, slimmer (85 %) and 8 % bigger, gripping a yellow two-plate dumbbell with a visible bar; then lowered 2 dp and enlarged to 62 dp in the 108 dp layer (optical centring, still inside the 66 dp safe zone). `tool/icon/fist_dumbbell_painter.dart` holds the geometry, measured in the first icon's 512 px units; `flutter test tool/icon` re-renders every layer and `build/icon_preview.png`. Version `1.0.2+9`. The owner decides the icon from preview images: always send one before changing it.
- v1.0.4 reminders (moved before cloud sync; Notion Development version 1.04; there is no 1.0.3):
  - **Settings › Reminders** (`settings/presentation/reminders_section.dart`, after Streak): Training reminder (weekday picker, default Mon/Wed/Fri, last day can't be turned off; time, default 18:00) and Weigh-in reminder ("Remind me after" N days, 1–60, default 14; time, default 08:00). Both off by default. Turning one on goes through `SettingsController.setReminder`, which asks the permission first; refused → stays off + "Notifications are off" dialog. `ValueChevron` moved to its own file.
  - **Storage**: settings rows `reminder.training.enabled/days/time`, `reminder.weigh_in.enabled/after_days/time` (times in minutes after midnight), parsed into `ReminderSettings` (`AppSettings.reminders`). No schema change.
  - **Rule** (pure, `settings/domain/reminders.dart`): `ReminderPlanner.plan(settings, facts, now, location)` → one-shot `ReminderOccurrence`s up to 56 days ahead, local wall-clock times via the `timezone` package (DST-safe). Training skips today if a completed workout ended today (local day) or one is in progress. Weigh-in fires each day once the last entry is ≥ N calendar days old (or none), with the day count. Ids = kind base (1e8 / 2e8) + yyyymmdd, so a re-plan only touches what changed.
  - **Runtime** (`settings/presentation/reminder_runtime.dart`, started from `App.build` next to `WorkoutRuntime`): `reminderFactsProvider` watches only the data of enabled reminders (program next session, active workout, workout summaries, bodyweights); the plan is re-applied on any change, on app resume (time zone re-read) and at launch (first apply reschedules everything: a force-stop drops alarms while the plugin still lists them). Taps: payload `training@…` → `router.go(Routes.today)`, `weighIn@…` → Profile + `weighInRequestProvider` (Profile opens `logWeightFlow`); also from a cold start (`takeLaunchPayload`).
  - **Platform** (`core/notifications/`): `NotificationCenter` = the one plugin instance, initialised once (shared with `LocalWorkoutNotifier`, single tap stream). `ReminderScheduler` interface + `LocalReminderScheduler` (diff against `pendingNotificationRequests`, exact alarms when allowed, channel `reminders`, scheduled in UTC because the instant is computed in Dart). Device time-zone id from MainActivity's `com.leflavb.mybodybuildingprogram/time` channel. Manifest: `RECEIVE_BOOT_COMPLETED` + the plugin's `ScheduledNotificationBootReceiver` (boot, package replaced). Tests use `FakeReminderScheduler` (`test/helpers/fakes.dart`, wired in `TestApp` as `app.reminders`; `tap(payload)`, `launchPayload`, `grantPermission`).
  - Why one-shots: the plugin's repeating schedules (`matchDateTimeComponents`) always fire the next match from now (can't skip a day) and can't change text. Trade-off: reminders stop if the app isn't opened for 8 weeks.
  - Program empty state icon `replay` → `repeat` (the loop note under the session list still uses `replay`; only the empty state was in scope).
  - Tests: `test/domain/reminders_test.dart` (24), `test/widgets/v104_reminders_test.dart` (9); renders `tool/screenshots/v104_test.dart` → `design/screens/v104_*`. Version `1.0.4+10`.

**Next step:** the later items, in Notion Development order (fixes and small changes go on the 1.0.x line, e.g. 1.0.5): **1.1 Cloud sync** (Firebase Auth with Google, Firestore row mirror, Cloud Storage for user images, background sync with workmanager, restore; Settings › Cloud backup section, designed in `design/screens/settings_cloud-*`). The data layer is already sync-ready (`SyncedTable` columns, `dirty` flag, `SyncMerge`). Needs the owner's Firebase project and `google-services.json` (not committed) before anything can be tested on a device; ask before starting. Set its Notion row to In progress first.

**UI building blocks (M2):** `lib/app/widgets/`: `ImageWell`, `ExerciseImageView` / `ExerciseThumb` (seed image, user photo or muscle placeholder), `Overline`, `InfoLine`, `PillBadge`, `TabTitle`, `SearchField`, `AppFilterChip`, `BigButton`, `EmptyState`, dialogs (`showConfirmDialog`, `showTextPrompt`, `showAppSnackBar`), value dialogs (`showGoalDialog` for reps/seconds/rest with optional "max", `showLoadDialog`). Tonal buttons use `AppTheme.tonal(colors)` (the M3 `FilledButton.tonal` would be yellow here). App bars: back-arrow screens use the theme's title spacing (title at 56 dp); tab screens set `titleSpacing: AppSpacing.lg`. Strings are all in `lib/app/strings.dart`.

**Gotchas met in M2:**
- Database watchers (`SyncedWrites.watching`) listen to drift's table-update notifications. Don't go back to a shared `customSelect(...).watch()`: drift caches watched queries by SQL, so watchers shared one stream (fixed in M2; regression test in `test/data/program_repository_test.dart`).
- Widget tests: call `app.settle(tester)` after anything that writes; `tester.pump()` after `enterText` before tapping a button that depends on the text; use `ensureVisible` (not `scrollUntilVisible`) to reach widgets already built off-screen; scope `find.byType(Scrollable)` to the current screen (tabs behind it have scrollables too).
- Screenshots (`tool/screenshots/`) turn on real shadows (`debugDisableShadows = false`); the default test mode draws a black outline instead. `test/helpers/demo_data.dart` builds the design's sample program (Pull A → Push A (next) → Legs, a "level" unit).
- Avoid `cond ? a = x : b = y..remove(z)`: the cascade applies to the whole conditional (this was the muscle-filter bug).

**Where the data layer is (M1):**
- `lib/core/db/`: `tables/` (4 layers; every synced table mixes in `SyncedTable`: id, created_at, updated_at, deleted_at, dirty), `daos/` (`SyncedWrites` stamps the sync columns: always write through `insertSynced` / `patch` / `softDelete`), `app_database.dart` (schema v1; creates the built-in `kg` unit and the single program with fixed ids), `seed/seed_importer.dart`, `database_provider.dart`.
- `lib/features/*/domain/`: pure Dart entities (freezed) and rules: `Rotation`, `EstimatedDuration`, `PlanFormat`, `PlanDiff` ("Update the program?"), `WorkoutClock` (pause, 12 h auto-finish, rest), `SwapRule`, `Records`, `ChartSeriesBuilder`, `LastTime`, `StreakRule`, `StatsRule`, `BodyWeightTrend`, `planSeedMerge`; `lib/core/sync/sync_merge.dart` (`SyncMerge`, for v1.1).
- `lib/features/*/data/`: `CatalogueRepository` (exercises, muscles, personal notes), `UnitsRepository`, `SettingsRepository`, `BodyWeightRepository`, `ProgramRepository`, `WorkoutRepository` (start/log/rest/pause/swap/finish/discard/auto-finish/apply changes), `HistoryRepository` (logged sets and workout summaries: the input of every derived figure).
- `lib/app/bootstrap.dart`: before the first screen, imports the seed (first launch or new seed version), closes a workout idle for more than 12 h, loads the settings.
- Derived data (PRs, charts, streak, stats, last time) is never stored: controllers compute it from `HistoryRepository` with the domain rules.

**Changing the database:** edit the tables, bump `schemaVersion`, run `dart run drift_dev make-migrations` (dumps `drift_schemas/`, regenerates `lib/core/db/app_database.steps.dart` used by `stepByStep` in `app_database.dart`, and creates `test/core/db/migrations/app_database/`, which we delete), add the `fromNToN+1` step, then `dart run drift_dev schema generate --data-classes --companions drift_schemas/app_database test/core/db/migrations/generated/` followed by `dart format`. `test/core/db/migration_test.dart` migrates every dumped version and checks v1 data survives (extend it with each new version). `test/core/db/app_database_test.dart` fails when the tables and the dump disagree. Write the data-model change in Notion > Data & Sync first.

**Tests:** `test/domain` (pure rules), `test/core/db` (schema, built-ins, seed import with the real seed), `test/data` (repositories on an in-memory database, including the full flow start → log → finish → history/PRs/pointer), `test/app` (widget tests). Helpers: `test/helpers/test_env.dart` (`TestEnv`: in-memory database + every repository + a fake clock) and `test/helpers/test_app.dart` (`TestApp`: the whole app on an in-memory database; call `app.settle(tester)` after anything that writes to the database).

**Gotchas met in M3:**
- Widget tests: a database write run with `tester.runAsync` while queries started by the widgets are still pending deadlocks (drift's lock is held by a query waiting on the fake-async zone). Always `app.settle(tester)` between two `runAsync` database calls; `test/widgets/m3_workout_test.dart` has a `db()` helper that does both.
- `WorkoutRuntime` is started from `App.build` (not the bootstrap) so its rest timer lives in the app's zone; in tests it then fires with `tester.pump(duration)`.
- Never read `ref` lazily in `dispose()` (`late final x = ref.read(...)` evaluated in dispose throws): read it in `initState`.
- A widget that repaints on a periodic timer must only `setState` when what it shows changes, or `pumpAndSettle` never returns (timed set view).
- The test font (Ahem) is wider than Inter: rows of buttons need `Wrap`/`Expanded` or they overflow in widget tests.
- `DateFormat` must be used without an explicit locale (see `core/utils/date_text.dart`).
- Helpers: `test/helpers/workout_data.dart` (`WorkoutData`: past history, `richHistory(weeks:)` with rising loads and leg curl switching kg → level, Push A in progress at various points) on top of `DemoData`.

**Gotchas met in M4:**
- A `PopupMenuItem.onTap` that opens a dialog: the menu then pops the top route, i.e. the dialog. Use the button's `onSelected` instead.
- Don't shadow the screen's `context` in `itemBuilder: (context) => …` when an item's action needs the screen.
- In widget tests the body comes before the AppBar in the element tree: scope `find.byIcon(...)` to `find.byType(AppBar)` for app-bar actions.
- After `git checkout -B <branch> origin/main` the upstream is `main`: push with `git push -u origin <branch>` (a bare `git push` is refused).

**How the app session works (owner's instructions):**
- One PR per milestone from the session's branch, CI green, squash-merge, then bring the branch back in line with `main`. Notion Development row: In progress → Done. Report in chat + push notification after each milestone.
- Decisions go to Notion > Technical > Decisions first, then the code.
- After M3 and every later milestone is merged: run the "Release APK" workflow on main, check it succeeded, and put the release link in the report (the owner installs from the release page on the phone). Artifact downloads are blocked in the cloud environment, so never try to download the APK, and never build a release APK locally.

**Toolchain facts (Flutter 3.50 / Dart 3.14):**
- Material lives in the `material_ui` package: import `package:material_ui/material_ui.dart`, never `package:flutter/material.dart` (deprecated). Icons are `Symbols.*_rounded` from `material_symbols_icons` (`fill: 1` for the filled variant).
- Dart 3.14 constructor style is enforced by the lints: `const new({...})` and `factory name(...)` inside the class. `dart fix --apply` rewrites the old style.
- Generated code (`*.g.dart`, `*.freezed.dart`) is git-ignored: run `dart run build_runner build --delete-conflicting-outputs` after cloning or changing annotated files.
- Android: `compileSdk 37` (androidx.core needs it), target = Flutter default (36), `minSdk 26`, core library desugaring on (needed by `flutter_local_notifications`). Application id `com.leflavb.mybodybuildingprogram`: never change it.
- In the Claude cloud environment, Gradle needs two init scripts in `~/.gradle/init.d/`: the environment's own `maven-mirror.gradle`, plus `tools/env/gradle-plugin-mirror.gradle` from this repo (copy it there). Without the second one the Flutter Gradle plugin fails to resolve Kotlin artifacts. The Android platform/build-tools/NDK/CMake are downloaded by the first Gradle build.

**Design checks:** `flutter test tool/screenshots` renders real screens (412 × 915 dp @2x, real fonts) to `build/screenshots/`; compare with `design/screens/*.png`. `tool/screenshots/harness.dart` has the helpers; add one `*_test.dart` per milestone.

**Release signing:**
- The release keystore (`mbp-release.jks`, alias `mbp-release`) was generated in the M0 session and **given to the owner**; it is not in the repo and never will be. SHA-256 of the certificate: `34:A1:93:EC:C4:C9:C9:55:4C:71:8C:EE:44:67:DB:92:B3:0B:D3:39:C5:49:A8:61:0A:AF:7A:07:59:20:64:D7`. **Never generate a new key**: an APK signed with another key cannot update the installed app.
- Releases are built only by `.github/workflows/release.yml` ("Release APK"), from the repository secrets `RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD` (set and working). The workflow builds the APK, runs `apksigner verify --print-certs` and **fails unless the certificate SHA-256 equals the one above** (`EXPECTED_CERT_SHA256` in the workflow), then publishes the GitHub release `v<pubspec version>` with `my-bodybuilding-program-<version>.apk` attached.
- Flow after each milestone: merge the PR → run "Release APK" with `workflow_dispatch` on `main` (a manual run on another branch builds and checks but publishes nothing; pushing a `v*` tag also publishes) → check the run succeeded → give the owner `https://github.com/le-flav-b/my-bodybuilding-program/releases/tag/v<version>`. Re-running for an existing version replaces the APK of that release.
- Local signing (`android/key.properties`, git-ignored) is not used from the cloud environment.
