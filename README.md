# My Bodybuilding Program

A personal Android app (Flutter) that tells me what to train next, guides me through each workout set by set with rest timers, logs every set, and shows my progress (charts, personal records, streaks, bodyweight).

- **Single user**, **English only**
- **Offline-first:** everything works without a network. An optional Google sign-in backs up and syncs data to Firebase.
- One editable **program**: a rotation of sessions (seeded with a Push / Pull / Legs split) built from a library of 88 exercises with illustrations.

## Links

- **Spec (master copy):** [Notion: My Bodybuilding Program](https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30) (+ sub-page *Exercise seed (EN)*)
- **Design:** [Figma: My Bodybuilding Program](https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program)
- **Rules for contributors / Claude sessions:** [`CLAUDE.md`](CLAUDE.md)
- **Project status and handoff:** [`legacy/HANDOFF.md`](legacy/HANDOFF.md)

## Repository layout

| Path | Content |
|---|---|
| `docs/seed/` | Translated seed data (`exercises.csv`, `program.csv`), mirrors of the Notion seed page |
| `legacy/` | Material from the first attempt (French), kept for reference only |
| `lib/`, `test/`, `android/` … | Flutter app (from milestone M0) |

## Build

> To be filled in at milestone M0 / M7.

```bash
# Prerequisites: Flutter (stable), Android SDK, JDK 17
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

Release APK: *TBD (M7)*. Firebase setup (`google-services.json`, not committed): *TBD (M6)*.
