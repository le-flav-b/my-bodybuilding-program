# CLAUDE.md: rules for every session

## Sources of truth

| What | Where |
|---|---|
| Spec (master) | Notion, [My Bodybuilding Program](https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30): **Features**, **Screens & Navigation**, **Data & Sync**, **Technical**, and the **Development** database (milestones + status) |
| Design | [Figma](https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program) (file key `ut2qBne1bdpEzGoDeNldNK`) |
| Technical rules | this file |
| Status / handoff | `legacy/HANDOFF.md`: read first, update last |

**Notion first.** Any change to behaviour, scope, screens, data model or a decision is written in Notion *before* the code. Never let Notion and the code disagree silently; if they conflict, stop and ask. When you start or finish a milestone, update its row in the Notion **Development** database (Status).

The spec describes the *system*. Catalogue content (exercises, muscles, patterns, images) is data produced by a separate task in the seed format defined in Notion > Technical. Don't invent or hard-code catalogue content in the app.

## Product constraints (non-negotiable)

- Android only, single user, **English only** (UI, code, comments, commits, asset names).
- **Offline-first**: every feature works with no network and no account. The UI reads and writes only the local database.
- Google sign-in is optional and only enables cloud backup/sync.
- **Nothing hard-coded that the user manages**: exercises, muscles, movement patterns and load units are database rows. Only `kg` is a built-in unit.
- Load units are never converted.

## Stack

| Concern | Choice |
|---|---|
| Framework | Flutter stable, Dart 3 |
| Android | minSdk 26, target latest; sideloaded APK |
| State / DI | Riverpod with code generation (`riverpod_annotation`, `riverpod_generator`) |
| Navigation | `go_router`: StatefulShellRoute for the 4 tabs (Today, Program, Progress, Profile) + full-screen workout routes |
| Local DB | Drift (SQLite) with versioned migrations and schema dumps |
| Models | `freezed` + `json_serializable` |
| Cloud | Firebase Auth (Google), Cloud Firestore (row mirror), Cloud Storage (user images) |
| Background | `workmanager` (periodic sync) |
| Notifications | `flutter_local_notifications` (rest timer: ongoing countdown + alert at the end) |
| Charts | `fl_chart` |
| Images | `image_picker` + compression (max 1080 px, JPEG) |
| Other | `wakelock_plus`, `uuid` (v7), `intl` |
| Lints | `very_good_analysis`; zero warnings |

Adding a dependency beyond this list: justify it in the PR description and add it to Notion > Technical.

## Architecture

```
lib/
  main.dart
  app/          # app widget, router, theme (tokens from Figma), strings
  core/         # db (tables, DAOs, migrations, seed import), sync, notifications, images, utils
  features/
    today/ workout/ program/ catalogue/ progress/ profile/ settings/
      data/          # repositories (wrap DAOs)
      domain/        # pure Dart: entities + rules
      presentation/  # screens, widgets, controllers/providers
assets/
  seed/         # seed JSON + images (delivered by the data task)
  fonts/        # Kameron Bold (logo), Inter (UI)
```

- UI → controllers → repositories → Drift. **The UI never imports Firebase or Drift.**
- **Domain rules are pure Dart** (no Flutter imports): rotation pointer, PRs, chart series (multi-unit), last-time lookup, streak, stats, estimated duration, sync merge, seed merge.
- **Four data layers** (see Notion > Data & Sync): catalogue / personal / plan / history. A workout **copies** its plan when it starts and never reads the plan again.
- PRs, charts, stats and streak are **computed** from `workout_sets` (a cache is allowed, never the source of truth).
- Every synced table has `id` (UUID v7), `created_at`, `updated_at` (UTC), `deleted_at` (soft delete); writes go through repositories that set them.
- Each logged set is persisted immediately (crash safety); a workout must survive app kill and reboot.
- Seed import: insert new `seed_key`s; update existing seeded rows only if `user_modified` is false; never re-create rows the user deleted.
- Sync: push dirty rows, pull `updated_at > last_pulled_at`, last write wins per row; Firestore offline cache disabled; paths `users/{uid}/{table}/{id}` and `users/{uid}/images/{id}`.
- Strings are centralised (one place), English only.

## Conventions

- `dart format`, `flutter analyze` clean.
- Files `snake_case.dart`; one public widget per file; `const` where possible.
- Tables plural snake_case; Dart classes singular PascalCase.
- Store times in UTC, display local. Durations in seconds (int). Loads as decimal + unit id.
- No `print` (use a logger). No secrets in the repo (`google-services.json`, keystores are git-ignored).
- Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`).
- One branch + one PR per milestone; CI green before merge.

## Testing

- Unit tests for every domain rule (listed above), including multi-unit charts/PRs and seed merge.
- Drift tests on an in-memory DB: repositories, migrations, seed import (first launch + update without overwriting edits).
- Widget tests: Today (normal / in progress / empty program), workout player (log set, rest timer, timed set, swap, finish/leave), session editor.
- Integration test: start next session → log all sets → finish → history, PRs and next session updated.
- Firebase mocked (`fake_cloud_firestore`, `firebase_auth_mocks`); tests never hit the network.
- CI (GitHub Actions): `flutter analyze` + `flutter test --coverage`; aim for ≥ 80 % on `domain/` and `core/`.

## Milestones

Details and status are in the Notion **Development** database.

| Version | Milestone | Done when |
|---|---|---|
| 0.1 | M0 Setup | App launches with 4 empty tabs in light/dark; CI runs on PRs |
| 0.2 | M1 Data layer | All tables + migrations, repositories, seed import, domain rules unit-tested |
| 0.3 | M2 Catalogue & program | Catalogue (with own exercises + photos), my exercise data, units & taxonomy settings, program/session editor |
| 0.4 | M3 Workout | Today, preview, player, list view, logging, swap, rest timer + notifications, resume, summary, update-program prompt |
| 0.5 | M4 Progress | History + edit, multi-unit charts, PRs + trophy, calendar + streak |
| 0.6 | M5 Profile | Bodyweight, stats summary, complete Settings |
| 0.7 | M6 Cloud | Auth, sync, image storage, background sync, restore |
| 1.0 | M7 Release | Icon, splash, polish, signed APK in a GitHub release, README build section |
| 1.1+ | Later | Progress photos → reminders → supersets, media controls, export/import |

## Session workflow

1. Read `legacy/HANDOFF.md`, this file, and the relevant Notion pages (plus Figma frames for UI work).
2. Work on the assigned branch only; keep the PR to one milestone.
3. Run `flutter analyze` and `flutter test` before pushing.
4. Update Notion (spec changes + Development status), then `legacy/HANDOFF.md`, before finishing.
