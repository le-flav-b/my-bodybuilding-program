# CLAUDE.md: rules for every session

## Sources of truth

1. **Notion** (master spec): https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30, with the sub-page *Exercise seed (EN)*.
2. **Figma** (design): https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program (file key `ut2qBne1bdpEzGoDeNldNK`).
3. **This file**: technical rules.
4. `legacy/HANDOFF.md`: current status, read first and update last.

**Rule: Notion first.** If a change touches behaviour, scope, screens, data model or a decision, update Notion *first* (spec + decisions log), then the code. If `docs/seed/*.csv` changes, update the Notion seed page in the same session. Never let Notion and the code disagree silently. If they conflict, stop and ask.

## Product constraints (non-negotiable)

- Android only, single user, English only (UI, code, comments, commits, asset names).
- **Offline-first:** every feature must work with no network and no account. The UI reads and writes only the local database.
- Sign-in (Google) is optional and only enables cloud backup/sync.
- Units: kg only. Dumbbell weights are per dumbbell.

## Stack

| Concern | Choice |
|---|---|
| Framework | Flutter stable, Dart 3 (null-safe, records/patterns OK) |
| Android | minSdk 26, target latest; sideloaded APK |
| State / DI | Riverpod 2 with code generation (`riverpod_annotation`, `riverpod_generator`) |
| Navigation | `go_router` (StatefulShellRoute for the 4 tabs) |
| Local DB | Drift (SQLite) with versioned migrations and schema dumps |
| Models | `freezed` + `json_serializable` |
| Cloud | Firebase Auth (Google), Cloud Firestore (mirror), Cloud Storage (photos, later) |
| Background | `workmanager` (periodic sync) |
| Notifications | `flutter_local_notifications` (rest timer: ongoing countdown + exact alarm at the end) |
| Charts | `fl_chart` |
| Other | `wakelock_plus` (keep screen on), `uuid` (v7 ids), `intl` |
| Lints | `very_good_analysis` (or `flutter_lints` + strict); zero warnings |

Adding a dependency beyond this list: justify it in the PR description.

## Architecture

Feature-first, layered:

```
lib/
  main.dart
  app/            # App widget, router, theme (tokens from Figma), l10n strings
  core/           # db (Drift tables, DAOs, migrations, seed), sync, notifications, utils
  features/
    today/  workout/  program/  library/  progress/  body/  settings/
      data/         # repositories (wrap DAOs)
      domain/       # pure Dart: entities, rules (progression, PRs, e1RM, rotation, streak)
      presentation/ # screens, widgets, providers/controllers
assets/
  exercises/      # <seed_key>.png (English snake_case, from legacy/some_images)
  fonts/          # Kameron Bold (logo), Inter (UI)
  seed/           # exercises.json, program.json generated from docs/seed/*.csv
```

- UI → controllers/providers → repositories → Drift. **The UI never imports Firestore or Drift directly.**
- Domain rules are **pure Dart functions** with no Flutter imports, so they are fully unit-testable.
- Every synced table has `id` (UUID v7 text), `created_at`, `updated_at` (UTC ms), `deleted_at` (soft delete), plus local `sync_state`. Writes go through repositories that set these fields.
- Workouts store a **snapshot** of the planned targets. Never derive past workouts from the current program.
- PRs, e1RM (Epley, 1–12 reps), volume, streaks and suggestions are **computed**, not stored (caching is allowed).
- Sync: push dirty rows, pull `updated_at > last_pulled_at`, last write wins per row; Firestore offline cache disabled. Path `users/{uid}/{table}/{id}`.
- A workout in progress is persisted after every set. It must survive app kill and reboot.
- Strings: centralise user-facing text (ARB/`intl` or one strings file), English only.

## Conventions

- Dart style: `dart format` (80 cols), `flutter analyze` clean.
- Files `snake_case.dart`; one public widget per file; widgets small and `const` where possible.
- Names: tables plural snake_case; Dart classes singular PascalCase.
- Times in UTC in storage, local in UI. Durations in seconds (int), weights in kg (double, 0.5 step in UI).
- No `print`; use a logger. No secrets in the repo (`google-services.json` and keystores are git-ignored).
- Commits: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`).
- Git: one branch + one PR per milestone. CI must be green before merge.

## Testing

- **Unit tests (required)** for all domain rules: rotation pointer, progression suggestion, PR detection, e1RM, volume, streak, sync merge (LWW, soft delete).
- **Drift tests** with an in-memory database: DAOs, migrations (`drift_dev` schema tests), seed integrity (every program exercise exists, every image exists).
- **Widget tests** for key screens: Today, workout player (log set, rest timer, finish/leave), session editor.
- **Integration test** (`integration_test/`) for the full flow: start next session → log all sets → finish → history and PRs updated → next session advanced.
- Firebase is mocked (`fake_cloud_firestore`, `firebase_auth_mocks`); tests never hit the network.
- CI (GitHub Actions): `flutter analyze`, `flutter test --coverage`. Target ≥ 80 % coverage on `domain/` and `core/`.

## Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Setup | Flutter project, lints, CI, folder structure, theme tokens + fonts, router with 4 empty tabs (Today, Program, Progress, Settings), light/dark |
| M1 | Data layer | Drift schema + migrations, seed (88 exercises, PPL program, renamed images), repositories, tests |
| M2 | Library and program | Exercise library (search/filter/custom/archive), exercise detail/edit, program and session editor |
| M3 | Workout | Today, session preview, guided player + list view, set logging, rest timer + notifications, resume, summary |
| M4 | Progress | History + workout edit, per-exercise charts, PRs + celebration, calendar + streak, progression suggestions |
| M5 | Body | Bodyweight log + chart, quick log on Today |
| M6 | Cloud | Firebase Auth, push/pull sync, background sync, restore on new phone |
| M7 | Release | Icon, splash, polish, signed release APK in a GitHub release, README build section |
| Later | | Progress photos → reminders → supersets → media controls → export/import |

## Session workflow

1. Read `legacy/HANDOFF.md`, this file and the relevant Notion sections (plus Figma frames for UI work).
2. Work on the assigned branch only. Keep PRs scoped to one milestone.
3. Run `flutter analyze` and `flutter test` before pushing.
4. Update Notion (if the spec changed), then `legacy/HANDOFF.md` (status, next steps) before finishing.
