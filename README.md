# My Bodybuilding Program

A personal Android app (Flutter) to plan my training, guide me through each workout set by set, and see my progress over time.

- **Single user**, **English only**
- **Offline-first**: everything works without a network. Optional cloud backup (Firebase) comes after v1.0.
- **One program**: a loop of sessions, so the app always knows what's next.
- **Guided workouts**: one-tap set logging and a rest timer that works with the phone locked.
- **Modular**: exercises, muscles and load units (kg or custom, e.g. machine "levels") are managed in the app.
- **Progress from the logs**: charts, personal records, calendar and streak, bodyweight, stats.

## Links

- **Spec (master copy):** [Notion: My Bodybuilding Program](https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30): Features · Screens & Navigation · Data & Sync · Technical · Development
- **Design:** [Figma: My Bodybuilding Program](https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program)
- **Rules for contributors / Claude sessions:** [`CLAUDE.md`](CLAUDE.md)
- **Status and handoff:** [`legacy/HANDOFF.md`](legacy/HANDOFF.md)

## Build

> To be filled in during M0 (setup) and M6 (release).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

- Prerequisites: *TBD (M0)*
- Release APK: *TBD (M6)*
- Firebase configuration (`google-services.json`, not committed): *TBD (Cloud sync, v1.1)*
