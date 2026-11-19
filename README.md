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

Prerequisites: Flutter 3.50.0 (stable, Dart 3.14), JDK 21 and the Android SDK (platform 37, build-tools 36; Gradle installs what is missing).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generated code is not committed
flutter analyze
flutter test                      # unit + widget tests
flutter test tool/screenshots     # renders the screens to build/screenshots/ for design checks
flutter run                       # on a connected Android device
```

- **Release APK:** run the **Release APK** workflow (Actions tab → Release APK → Run workflow, on `main`), or push a `v*` tag. It builds the APK, signs it with the release key from the repository secrets (listed at the top of `.github/workflows/release.yml`), checks the certificate SHA-256 with `apksigner` (the run fails if it is not the release key), and publishes the GitHub release `v<pubspec version>` with `my-bodybuilding-program-<version>.apk` attached. Locally, `flutter build apk --release` signs with the release key only when `android/key.properties` exists (git-ignored; `storeFile`, `storePassword`, `keyAlias`, `keyPassword`), otherwise with the debug key, which cannot update an installed release.
- **Install on the phone:** open the [latest release](https://github.com/le-flav-b/my-bodybuilding-program/releases/latest) on the phone, download the `.apk`, and open it (allow "Install unknown apps" for the browser once). Updates install over the previous version and keep the data, as long as they are signed with the same key.
- **App icon:** `flutter test tool/icon` renders the launcher icon layers and the splash icon into `android/app/src/main/res`.
- **CI:** `.github/workflows/ci.yml` runs the seed validator, code generation, format check, `flutter analyze` and `flutter test --coverage` on every pull request.
- **Sandboxed build machines** where Maven Central is unreliable: see `tools/env/gradle-plugin-mirror.gradle`.
- Firebase configuration (`google-services.json`, not committed): *TBD (Cloud sync, v1.1)*
