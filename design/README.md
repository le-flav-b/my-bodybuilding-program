# Design: My Bodybuilding Program

Approved design (design session, 2026-11-15; v1.0.1 changes: manual personal records, "Bests" naming, no empty-state art, new app icon). **This folder is what app sessions read.** Figma mirrors it for viewing only (not updated for v1.0.1).

Since v1.0.1, "PR" means only a personal record logged by hand; the records computed from the training sets are called **Bests**. The HTML previews and the older screenshots still show the v1.0 labels ("New record", "PR" chips); where they differ, this file and the `screens/v101_*` renders win.

| What | Where |
|---|---|
| Tokens (colours light/dark, type, spacing, radius, sizes) | [`tokens.json`](tokens.json) |
| HTML source of every sheet and screen, light + dark | [`preview/index.html`](preview/index.html) |
| Clickable prototype (all flows) | [`preview/prototype.html`](preview/prototype.html) |
| Screenshots `<screen>_<state>_<theme>.png` + component sheets | [`screens/`](screens/) |
| v1.0.1 screens rendered from the app (`flutter test tool/screenshots`) | [`screens/v101_*.png`](screens/) |
| What is in Figma and what is left there | [`figma.md`](figma.md) |

Behaviour is specified in Notion (Features, Screens & Navigation). This file covers **visuals and layout**: what each screen is made of, sizes, states and interactions. Where a screen detail added during the design changed the spec, Notion was updated first.

---

## 1. Foundations

### Theme
- Material 3, `useMaterial3: true`. Build both `ThemeData`s from `tokens.json`: `color.light` / `color.dark` map 1:1 to `ColorScheme` fields (`primary`, `onPrimary`, `primaryContainer`, `surfaceContainerLow`, …). The non-M3 roles (`brand`, `brandLight`, `trophy`, `trophyText`, `success`, `imageWell`, `chart1..4`) go in an `AppColors` `ThemeExtension`.
- Theme mode: System / Light / Dark (Settings).

### Colour decisions (WCAG AA)
| Pair | Ratio | Use |
|---|---|---|
| White on brand coral `#F55E42` | 3.1:1 ✗ | Never for text. Coral is **brand** only: logo, rest-timer ring, large graphics. |
| `#FCFCFC` on light `primary` `#C23E27` | 5.1:1 | Light theme buttons, active states |
| `#181B1E` on dark `primary` `#F68974` | 7.2:1 | Dark theme buttons (dark text on light coral) |
| Yellow `#FFC854` | 1.5:1 on light | Fill only (trophy, Best / PR chips) with dark text `#181B1E`. Text on light: `trophyText` `#8A5A00`. |
| Chart series `chart1..4` | ≥ 3:1 vs surface | One colour per load unit, in order of first use on the exercise |

Yellow is reserved for records (trophy, training-best chips/points, personal records) and the personal setup note strip (`secondaryContainer`). Selected states use `primaryContainer`.

### Type (Inter; Kameron Bold for the logo only)
`timer` 96/104 600 tabular · `displaySmall` 40/48 600 tabular · `headlineLarge` 32/40 700 · `headlineMedium` 28/36 700 · `headlineSmall` 24/32 600 · `titleLarge` 22/28 600 · `titleMedium` 16/24 600 · `titleSmall` 14/20 600 · `bodyLarge` 16/24 · `bodyMedium` 14/20 · `bodySmall` 12/16 · `labelLarge` 14/20 600 · `labelMedium` 12/16 600 · `labelSmall` 11/16 600 · `logo` Kameron 22/28.
Every number that changes live (timers, steppers, stats) uses tabular figures (`FontFeature.tabularFigures()`).

### Spacing, radius, sizes
- 4-pt grid: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`. Screen padding 16.
- Radius: `xs 4` (text fields, snackbar) · `sm 8` (chips, thumbnails, menus) · `md 12` (image wells, steppers) · `lg 16` (cards, rows, FAB) · `xl 28` (hero cards, dialogs, bottom sheets) · `full` (buttons).
- Touch targets ≥ 48. Buttons 48 high; **big** buttons 64 high / 18 sp for the one main action of a screen (Start, Done, Finish, Stop, Resume). App bar 64, nav bar 80.

### Icons
Material Symbols **Rounded** → Flutter `Icons.<name>_rounded` (no extra package). Filled variant for the active nav tab and for play/trophy/fire. Names used: `today`, `fitness_center`, `monitoring` (→ `Icons.insights_rounded` if missing), `person`, `play_arrow`, `pause`, `stop`, `check`, `close`, `add`, `remove`, `history`, `schedule`, `timer`, `skip_next`, `swap_horiz`, `view_list`, `drag_indicator`, `more_vert`, `edit`, `edit_note`, `push_pin`, `trophy` (→ `Icons.emoji_events_rounded`), `local_fire_department`, `flag`, `block`, `delete`, `inventory_2`, `restore`, `straighten`, `accessibility_new`, `settings`, `contrast`, `cloud_upload`, `sync`, `add_a_photo`, `photo_camera`, `image`, `exercise` (→ `Icons.fitness_center_rounded`), `done_all`, `menu_book`, `replay`, `visibility_off`, `lock`, `info`.
Fallbacks where the Symbols name has no `Icons` constant: `monitoring` → `insights`, `trophy` → `emoji_events`, `exercise` → `fitness_center`. If the coding session prefers exact glyphs, adding `material_symbols_icons` is a dependency decision (Notion > Technical).

### Images
- Exercise illustrations have white backgrounds → always shown in an **image well**: `imageWell` `#FCFCFC` fill, radius 12, `BoxFit.contain`, 1 px `outlineVariant` inset border in light theme. Same in dark theme (white tile).
- No image → **placeholder by primary muscle**: region photo (`chest/triceps`, `back/biceps`, `legs`, `abs`; shoulders → chest) shown `cover`, 55 % opacity, desaturated, with the muscle name in a small white label at the bottom. Exported region images: `preview/assets/img/placeholder_*.png` (from `legacy/`).
- `trophy.png` for the "New best" overlay. Empty states have no illustration (v1.0.1): they use an icon in a 96 circle.
- **App icon** (v1.0.2, `tool/icon/fist_dumbbell_painter.dart`): a fist gripping a dumbbell, flat with no outlines, on brand coral. The hand is the first app's icon redrawn (thumb block with its tip over the index finger, finger tops stepping down to the little finger, knuckle line, curved thumb line, diagonal wrist, wrist crease), narrowed to 85 % and enlarged 8 %; off-white `#FCFCFC`. The dumbbell is brand yellow, two plates per side with the bar visible next to the hand. Parts are separated by thin transparent gaps (so the monochrome themed icon reads). In the 108 dp layer: 62 dp wide, 2 dp below centre (optical centring), inside the 66 dp safe zone. Same drawing on the Android 12+ and older splash. Launcher label "My Program".
- English asset names are in `preview/assets/img/`.

---

## 2. Components

See `screens/components_1..4.png` and `preview/components-*.html`.

| Component | Spec |
|---|---|
| **Bottom nav** | M3 `NavigationBar`, 80 high, `surfaceContainer`. 4 destinations: Today `today`, Program `fitness_center`, Progress `monitoring`, Profile `person`. Labels always shown; active = filled icon in a 64×32 `primaryContainer` pill. Hidden during the workout. |
| **Buttons** | Filled / tonal / outlined / text, 48 high, pill. Big = 64 high. Destructive = `error` text button. Icon button 48. Extended FAB 56, radius 16, `primaryContainer`. |
| **Session card** (Today) | `surfaceContainer`, radius 28, padding 20. Overline "Next session · n of N" (primary), name `headlineMedium`, meta row (exercises, ~duration, last done) with 18 px icons, up to 5 thumbnails 48×48 (radius 8) + "+n", big Start, row of 3 text buttons: Other session · Empty · Skip. |
| **Session row** (Program, pick sheet) | ≥ 72 high, `surfaceContainerLow`, radius 16. Drag handle, number in a 32 circle, name + meta, `play_circle` icon button. Next session: `primaryContainer` + "Next" badge (primary pill, 20 high). |
| **Exercise row** | ≥ 80 high. Image well 64, name `titleMedium`, planned sets `bodyMedium` ("4 × 10 · 40 kg", pyramid "12, 10, 8 · 5–7 level", time "3 × 0:45", "3 × max"), last time `bodySmall` with `history` icon. Variants: catalogue (muscles instead of sets, chevron), workout-list status (leading 28 status circle: done `success` ✓ / now `primary` ▶ with tinted row / to do outline ring / skipped grey + strike-through). |
| **Set row** | Done: 24 circle `success` ✓, logged value, "last …" right; "Best" trophy chip if it beat a training best. Upcoming: grey number, target, last. **Current set card**: `surfaceContainer` radius 16, header (primary number, "Target …", "Last …"), two steppers, big **Done**. "Add set" text button below the list. |
| **Stepper** | Label (Reps / Time / Load + unit chip), − and + round 48 buttons, value 32 sp tabular. Pre-filled with the target; a changed value turns `primary`. Reps ±1, time ±5 s, load ± unit step. No load = "Body", negative = "−10" (assisted). Long-press the value → keyboard entry. |
| **Unit chip + menu** | 24-high outlined chip "kg ▾" on the load stepper. Menu: units with their step, selected = `primaryContainer` + check, separator, "Manage units". Applies to the remaining sets of that exercise. |
| **Rest timer** | Ring 280, stroke 12, track `surfaceContainerHigh`, progress `brand`, round cap, drains clockwise from 12 o'clock. Centre: "REST" label, time `timer` 96 sp, "of 1:30". Controls: −15 and +15 round 64 buttons, tonal big Skip. Next-up card below (next set, or next exercise after the last set). |
| **Timed-set timer** | Same ring. Lead-in: `secondary` (yellow) ring, "GET READY", 3-2-1 with beeps. Hold: `primary` ring counts down, "target · last" under the time, big **Stop**; at 0 → beep, set logged automatically, rest starts. Max: no progress arc, counts up, shows best. |
| **Trophy chip** (`TrophyChip`, was PR chip) | 24 high pill, `trophy` fill, dark text, filled trophy icon: "Best" (training best, default), "Best PR" (personal records), "Heaviest · 42.5 kg", "Longest hold · 1:20". |
| **Multi-unit chart** (`fl_chart`) | In a `surfaceContainerLow` card. One point per workout (best load / best reps / best time). Each unit its own colour (`chart1..4`) and scale: first visible unit → left axis, second → right axis, others drawn without labels. Unit name above each axis in its colour. Lines only join points of the same unit. Best points: 6 px `trophy` dot with dark outline. Tap/drag: dashed vertical cursor + inverse-surface tooltip (date, best set, "Best"). Legend chips toggle units. Range segmented row 1M / 3M / 6M / 1Y / All. |
| **Calendar month** | Header month + chevrons (next disabled on current month). 7 columns Mon–Sun + a narrow week column. Trained day: 40 circle `primary`; 2 workouts: small dot; today: ring. Week column: `check_circle` brand = target reached, ring = missed, … = current week. Below: streak chip + "Best: n weeks". |
| **Streak chip / week strip** | Chip 32 high, `secondaryContainer`, brand fire icon, "2 weeks"; "No streak" grey. Week strip: 7 × 36 circles, trained `primary`, today ringed. |
| **Stat tile** | `surfaceContainerLow`, radius 16, label `bodySmall` + icon, value 28 sp tabular (units small, grey), optional delta line `success` ↑ / `error` ↓. |
| **Dialogs** | `surfaceContainerHigh`, radius 28, padding 24, title 24 sp. Multi-choice: stacked full-width buttons, safest main action first, destructive last (red text). Two-choice: right-aligned text + filled. Leave workout (summary tiles + Finish now / Keep going / Discard), Resume workout (Resume / Finish with what's logged / Discard), Update the program? (list of changes + No, keep it / Update), archive/delete confirmations. |
| **Snackbar** | Inverse surface, radius 4, action in `inversePrimary` (e.g. "Set 3 removed · Undo"). |
| **Trophy overlay** | Full-screen dark scrim, `trophy.png` 260 wide + confetti burst, "NEW BEST" (yellow; was "New record" before v1.0.1), value 40 sp, "Exercise · best type", "Previous best: …", yellow big "Nice!". Closes on tap or after 4 s; rest timer keeps running (strip at the bottom). |
| **Resume banner** | `primary` card radius 28: pulsing dot "In progress · 38:12", session name, "Exercise 3 / 6 · 14 sets logged", 56 round play button (inverted colours). |
| **Empty state** | Centered: icon in a 96 circle (`surfaceContainer`, 40 icon), title 20 sp (24 for the first-launch welcome), body 14 sp max 280 wide, optional CTA. No illustrations. |
| **PR card** (`PrSummaryCard`, v1.0.1) | `surfaceContainerLow`, radius 16. 40 trophy circle (`trophy` fill when there is a PR, grey otherwise), overline "PERSONAL RECORD", best PR `titleLarge` 700 tabular (or "No PR yet"), "date · History · n", tonal 48 + button (Add PR), chevron. Tap → Personal records. |
| **PR dialog** (v1.0.1) | Dialog "Add PR" / "Edit PR": date button (today by default, no future dates), then for a reps exercise Load (optional) + unit dropdown, then Reps (helper "A load, reps, or both."); for a time exercise Time ("Minutes:seconds, or seconds") then Load + unit. Note (optional). Errors under the field. Cancel / Save. |
| **Exercise picker** | Modal bottom sheet ~90 % height, radius 28 top, grab handle. Title "Add exercise" / "Swap exercise" + "New" text button, subtitle when swapping, 56-high pill search, scrollable muscle filter chips (multi-select; swap starts on the current exercise's primary muscle), catalogue rows (well 56). |
| **Filter chips / search** | Chips 32 high radius 8, outlined; selected `primaryContainer` with check. "Archived" chip with `inventory_2`. |
| **Unit editor** | Dialog: Name (outlined field, helper "Shown after the value"), Step field, Decimals segmented 0/1/2, live preview "5 → 6 → 7 level". Edit adds "Archive" on the left. kg is locked. |
| **Settings tiles** | 56+ list tiles: leading icon, title/subtitle, trailing value + chevron, M3 switch, or inline − n + stepper. Section labels `titleSmall` in `primary`. |

---

## 3. Screens

Phone frame 412 × 915 dp. Status bar 24, gesture bar 24. Files: `screens/<screen>_<state>_<theme>.png`.

### Today (tab 1) · `preview/screens-today.html`
- **Layout**: app bar with the logo (Kameron, `brand`) → date overline + "Last workout yesterday" → **session card** → **week card** ("This week · 2 / 3" + streak chip + week strip) → **last workout card** (history icon, "Pull A · yesterday", "52 min · 18 sets · 1 best", chevron → Workout detail).
- **States**: `normal`; `after-workout` (next session advanced, week target reached); `in-progress` (Resume banner replaces the card, then an "Up next in Push A" card with the current exercise and set; tap banner → Player); `empty` (first launch: `fitness_center` icon in a 96 circle, "Welcome!", "Your program is a loop of sessions. Create the first one and this screen will always tell you what's next." (no example), big "Create your first session" → Session editor); `pick-session` (bottom sheet "Start another session", note that the pointer follows what you do, session rows with last done; play → Session preview).
- Empty workout → Player with no exercises (list view opens with "Add exercise"). Skip → pointer moves, snackbar with Undo.

### Session preview · `screens-workout.html`
Back, session name, edit (→ Session editor). Meta row. Info line "Changes here apply to this workout only." Exercise rows with drag handles (reorder; swipe/⋮: swap, remove, edit sets). "Add exercise". Sticky bottom bar with big **Start workout**.

### Workout player · `screens-workout.html`, `screens-workout-2.html`
- **Header** 56: close X (→ Leave dialog), session name + "elapsed · ~left" (tabular), **pause**, list view. Below: segmented progress bar, one 4-high segment per exercise (done `success`, current `primary`, skipped `outlineVariant`).
- **Rep-based** (`player_reps`): exercise block (well 96, "EXERCISE 1 / 6" overline, name 24 sp, muscles, "Form cues" expand, "Note" (exercise note), ⋮ = swap / skip / change unit) → personal setup note strip (`secondaryContainer`, pin icon) → set rows with the current set card → "Add set". Footer (`surfaceContainerLow`): "NEXT EXERCISE" + name/plan + thumbnail.
- **Resting** (`player_resting`): "Set 3 · 10 × 40 kg logged" row with Edit, rest timer, controls, next-up card, same footer. Replaces the set list while resting; returns to it on Skip / end.
- **Time-based** (`player_timed`): compact exercise header (well 72), set chips (done value / "Set 2" current / upcoming), timer ring (lead-in → hold), big Stop, helper line. Before Start, the current set card shows Time stepper + Log / Start (see components 2).
- **Best trophy** (`player_trophy`, v1.0.1 render `v101_player_trophy_*`): overlay "New best" as in components.
- **Paused** (`player_paused`): blurred surface over the player, 96 circle pause icon, "PAUSED", frozen elapsed time 72 sp, explanation + what's next, big Resume, Finish / Discard text buttons.
- Keep screen on (setting) applies here. Ongoing notification mirrors the rest countdown / "Paused".

### Workout list view · `screens-workout-2.html`
Back (to player), "Push A · exercises", "18:22 · 2 / 6 done", pause. Exercise rows with status + drag handles; current row tinted with ⋮ menu (Go to exercise, Swap, Skip, Change unit, Remove in red). "Add exercise". Sticky big **Finish workout** (→ summary flow). **Swap** opens the picker ("Replacing Overhead press. Sets already logged stay on it.").

### Workout summary · `screens-workout-2.html`
1. If the plan changed: **Update the program?** dialog first (list of changes; skipped exercises are listed but stay in the program).
2. Summary: "WORKOUT COMPLETE" overline, session name, date and time range; 3 tiles (Duration, Sets, Exercises x / y); "New bests · n" with best items (trophy circle, exercise · best type, value + "was …"); Workout note field; info line "Next session: Legs"; sticky big **Done** → Today.

### Program (tab 2) · `screens-program.html`
Title "Program". "Exercises" entry card (→ catalogue, count). "SESSIONS · LOOP OF 3" + "Drag to reorder". Session rows (tap body → editor, play → preview). Loop note "After Legs, back to Pull A". Extended FAB "Add session" → name dialog (label "Session name", no example hint). No sessions: icon empty state (`replay`, the loop) with "Create your first session".

### Session editor
Back, "Edit session", ⋮ (delete session). Name field. Exercise **cards** (drag handle, well 48, name, one-line summary "4 × 10 · 40 kg · rest 2:00", expand chevron). Expanded card: set table (# · Reps/Time · Load · Unit · ✕), 40-high value boxes ("max" in primary, "Body" grey, "+5"/"−10"), "Add set" (copies last), rest chip "Rest 1:30", delete exercise. Tonal block "Add exercise" (→ picker).

### Exercises (catalogue)
Back, "Exercises". Search ("Search 84 exercises"), chips row (Archived toggle + muscles). Catalogue rows → Exercise detail. Extended FAB "New exercise". No match → empty state with "Create '…'".

### Exercise detail / edit
- **Detail**: back + edit. Full-width image well 240. Name 26 sp, measure ("Reps"/"Time"), muscle chips (primary in `primaryContainer`), description with bullet cues, "My notes / setup" card (editable in place), Progress link card (best + count + sparkline) → Exercise progress, **PR card** (always shown) → Personal records (`v101_exercise-detail_bottom_*`).
- **Edit**: close + Save. Photo area 200 (no photo: `add_a_photo` + "the muscle placeholder is shown"), Camera / Gallery buttons. Name, description fields, Measure segmented (Reps / Time), muscle chips (tap 1 = primary filled, 2 = secondary tonal, 3 = off). Bottom: only the action that applies: Delete (never used) or Archive (has history) / Restore (archived).

### Progress (tab 3) · `screens-progress.html`
Title + M3 primary tabs **Calendar · Exercises · History**.
- **Calendar**: calendar month component, streak row, 2 tiles (workouts / time this month). Tap a trained day → Workout detail (or a short list if 2).
- **Exercises**: search, "Sorted by last done · n exercises", rows (well 52, name, "2 days ago · best 42.5 kg", 64×28 sparkline in `chart1`) → Exercise progress.
- **History**: month headers with totals, workout rows (date block 48×52, session name + best count badge, "52 min · 18 sets", chevron) → Workout detail.

### Exercise progress
Back, exercise name, ⓘ (→ Exercise detail). **PR card** first (v1.0.1). Then the overline "BESTS" and the best tiles (training bests), one per unit (left border in the unit's chart colour). Unit legend chips. Multi-unit chart + range. "All sets · n workouts" grouped by workout: date + session, set pills (unit dot, best pills yellow with trophy). No training yet: the PR card, then a small "Not done yet" note (64 circle `monitoring`) instead of the bests and chart (`v101_exercise-progress_default_*`).

### Personal records (v1.0.1) · `screens/v101_personal-records_*`
From Exercise detail, Exercise progress and Profile. App bar: back, "Personal records" with the exercise name below (`bodyMedium`, `onSurfaceVariant`), ⓘ (→ Exercise detail).
- **Default**: best card (`secondaryContainer`, radius 28, padding 20: "Best PR" trophy chip, value `displaySmall` 700 tabular, full date, note; if other series exist (other units, or no load) a divider, overline "IN OTHER UNITS" and one line each: value + date). Overline "HISTORY · n". PR rows newest first: value `titleMedium` tabular (+ "Best PR" chip on the current bests), "date · note" `bodyMedium`, ⋮ (Edit PR / Delete PR in red). Tap a row → Edit. Extended FAB "Add PR".
- **Empty**: icon empty state (trophy), "No PR yet", "A PR is an attempt you make on purpose, when you want. It stays apart from your training sets and their bests.", filled "Add PR".
- **Add / edit**: PR dialog (components). Delete asks "Delete this PR?" (destructive).

### Workout detail
Back, session name, ⋮ (delete workout). Meta (date/time, duration, sets). Workout note card (edit). Per exercise: thumbnail 40, name, ⋮ (exercise note, remove); set lines (number, value, PR chip, edit pencil → edit/delete set). Edits recompute PRs and charts.

### Profile (tab 4) · `screens-profile.html`
Title + gear (→ Settings). Bodyweight card (radius 28: "BODYWEIGHT · TODAY", value 32 sp, change vs last week, sparkline, filled + button → log entry; tap card → Bodyweight). Stat tiles (workouts, time, sets, streak · best, this month vs last for workouts and time). "Latest PRs" (v1.0.1): the 5 most recent personal records: 40 trophy circle (`trophy` fill), exercise name, date, value right → that exercise's Personal records (`v101_profile_latest-prs_*`). None: "Your personal records appear here. Add one from an exercise."

### Bodyweight
Back, "Bodyweight". Value 40 sp + change over 30 days (neutral colour). Trend chart (single `primary` line, last point dot, range row). Entries: value, date (+ note), change from previous, ⋮ (edit / delete). Extended FAB "Log weight" (dialog: date/time, kg, note).

### Settings, Load units, Muscles
- **Settings**: Appearance (Theme segmented System / Light / Dark) · Library (Load units with count + list, Muscles with count) · Workout (Default rest, Timer sound, Timer vibration, Keep screen on) · Streak (Weekly target − n +) · About (Version).
- **Load units**: info line "Loads are never converted between units." Rows: kg (lock, "Built in · step 0.5 · 1 decimal"), custom units ("Step 1 · 0 decimals · used in 2 exercises", edit → unit editor). "Archived" section with Restore. FAB "Add unit".
- **Muscles**: rows with exercise count + edit (rename); "Hidden" section (visibility_off). FAB "Add muscle".
- **Cloud backup (v1.1, not in v1)**: first Settings section. Signed out: card with `cloud_upload`, "Back up your training", explanation, outlined "Sign in with Google". Signed in: avatar, name, email, "Backed up 2 min ago" (`success`), Sync now (tonal) + Sign out (outlined).

---

## 4. Prototype flows

`preview/prototype.html` (open locally in a browser; light/dark toggle; "Show hotspots"). Hotspots come from `data-go` attributes in the screen HTML (`tools/build_proto.mjs` → `proto.js`).
1. **Main**: Today → Start → Session preview → Start workout → Player (Done) → Best trophy (Nice!) → Resting → list view → ⋮ Swap → picker → list → Finish workout → Update the program? → Summary → Done → Today with the next session advanced.
2. Pause: Player → pause → Paused → Resume.
3. Progress → Exercises → Exercise progress (and History → Workout detail).
4. Profile → Settings → Load units (and Muscles, Bodyweight).
5. Program → Exercises → Exercise detail → Edit / Progress.

## 5. Maintaining the previews

```
node design/preview/tools/build_tokens.mjs                      # tokens.json → tokens.css + tokens.js
VW=3200 node design/preview/tools/shoot.mjs screens-today.html ../screens '[data-shot]' 2
node design/preview/tools/build_proto.mjs                       # hotspots → proto.js
```
`shoot.mjs` uses the preinstalled Playwright. Shared styles: `preview/app.css`. The light/dark copies of each sheet come from one `<template>` (`review.js`).
