# Design: My Bodybuilding Program

Approved design (design session, 2026-11-15). **This folder is what app sessions read.** Figma mirrors it for viewing only.

| What | Where |
|---|---|
| Tokens (colours light/dark, type, spacing, radius, sizes) | [`tokens.json`](tokens.json) |
| HTML source of every sheet and screen, light + dark | [`preview/index.html`](preview/index.html) |
| Clickable prototype (all flows) | [`preview/prototype.html`](preview/prototype.html) |
| Screenshots `<screen>_<state>_<theme>.png` + component sheets | [`screens/`](screens/) |
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
| Yellow `#FFC854` | 1.5:1 on light | Fill only (trophy, PR chips) with dark text `#181B1E`. Text on light: `trophyText` `#8A5A00`. |
| Chart series `chart1..4` | ≥ 3:1 vs surface | One colour per load unit, in order of first use on the exercise |

Yellow is reserved for records (trophy, PR chips/points) and the personal setup note strip (`secondaryContainer`). Selected states use `primaryContainer`.

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
- `trophy.png` for PRs, `sleep.png` for the first-launch empty state (on a round light tile so its dark outlines read in dark mode).
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
| **Set row** | Done: 24 circle `success` ✓, logged value, "last …" right; PR chip if a record. Upcoming: grey number, target, last. **Current set card**: `surfaceContainer` radius 16, header (primary number, "Target …", "Last …"), two steppers, big **Done**. "Add set" text button below the list. |
| **Stepper** | Label (Reps / Time / Load + unit chip), − and + round 48 buttons, value 32 sp tabular. Pre-filled with the target; a changed value turns `primary`. Reps ±1, time ±5 s, load ± unit step. No load = "Body", negative = "−10" (assisted). Long-press the value → keyboard entry. |
| **Unit chip + menu** | 24-high outlined chip "kg ▾" on the load stepper. Menu: units with their step, selected = `primaryContainer` + check, separator, "Manage units". Applies to the remaining sets of that exercise. |
| **Rest timer** | Ring 280, stroke 12, track `surfaceContainerHigh`, progress `brand`, round cap, drains clockwise from 12 o'clock. Centre: "REST" label, time `timer` 96 sp, "of 1:30". Controls: −15 and +15 round 64 buttons, tonal big Skip. Next-up card below (next set, or next exercise after the last set). |
| **Timed-set timer** | Same ring. Lead-in: `secondary` (yellow) ring, "GET READY", 3-2-1 with beeps. Hold: `primary` ring counts down, "target · last" under the time, big **Stop**; at 0 → beep, set logged automatically, rest starts. Max: no progress arc, counts up, shows best. |
| **PR chip** | 24 high pill, `trophy` fill, dark text, filled trophy icon: "PR", "Heaviest · 42.5 kg", "Longest hold · 1:20". |
| **Multi-unit chart** (`fl_chart`) | In a `surfaceContainerLow` card. One point per workout (best load / best reps / best time). Each unit its own colour (`chart1..4`) and scale: first visible unit → left axis, second → right axis, others drawn without labels. Unit name above each axis in its colour. Lines only join points of the same unit. PR points: 6 px `trophy` dot with dark outline. Tap/drag: dashed vertical cursor + inverse-surface tooltip (date, best set, PR). Legend chips toggle units. Range segmented row 1M / 3M / 6M / 1Y / All. |
| **Calendar month** | Header month + chevrons (next disabled on current month). 7 columns Mon–Sun + a narrow week column. Trained day: 40 circle `primary`; 2 workouts: small dot; today: ring. Week column: `check_circle` brand = target reached, ring = missed, … = current week. Below: streak chip + "Best: n weeks". |
| **Streak chip / week strip** | Chip 32 high, `secondaryContainer`, brand fire icon, "2 weeks"; "No streak" grey. Week strip: 7 × 36 circles, trained `primary`, today ringed. |
| **Stat tile** | `surfaceContainerLow`, radius 16, label `bodySmall` + icon, value 28 sp tabular (units small, grey), optional delta line `success` ↑ / `error` ↓. |
| **Dialogs** | `surfaceContainerHigh`, radius 28, padding 24, title 24 sp. Multi-choice: stacked full-width buttons, safest main action first, destructive last (red text). Two-choice: right-aligned text + filled. Leave workout (summary tiles + Finish now / Keep going / Discard), Resume workout (Resume / Finish with what's logged / Discard), Update the program? (list of changes + No, keep it / Update), archive/delete confirmations. |
| **Snackbar** | Inverse surface, radius 4, action in `inversePrimary` (e.g. "Set 3 removed · Undo"). |
| **Trophy overlay** | Full-screen dark scrim, `trophy.png` 260 wide + confetti burst, "NEW RECORD" (yellow), value 40 sp, "Exercise · record type", previous record, yellow big "Nice!". Closes on tap or after 4 s; rest timer keeps running (strip at the bottom). |
| **Resume banner** | `primary` card radius 28: pulsing dot "In progress · 38:12", session name, "Exercise 3 / 6 · 14 sets logged", 56 round play button (inverted colours). |
| **Empty state** | Centered: art (sleep.png on a 200 round tile) or icon in a 96 circle, title 20 sp, body 14 sp max 280 wide, optional CTA. |
| **Exercise picker** | Modal bottom sheet ~90 % height, radius 28 top, grab handle. Title "Add exercise" / "Swap exercise" + "New" text button, subtitle when swapping, 56-high pill search, scrollable muscle filter chips (multi-select; swap starts on the current exercise's primary muscle), catalogue rows (well 56). |
| **Filter chips / search** | Chips 32 high radius 8, outlined; selected `primaryContainer` with check. "Archived" chip with `inventory_2`. |
| **Unit editor** | Dialog: Name (outlined field, helper "Shown after the value"), Step field, Decimals segmented 0/1/2, live preview "5 → 6 → 7 level". Edit adds "Archive" on the left. kg is locked. |
| **Settings tiles** | 56+ list tiles: leading icon, title/subtitle, trailing value + chevron, M3 switch, or inline − n + stepper. Section labels `titleSmall` in `primary`. |

---

## 3. Screens

Phone frame 412 × 915 dp. Status bar 24, gesture bar 24. Files: `screens/<screen>_<state>_<theme>.png`.

### Today (tab 1) · `preview/screens-today.html`
- **Layout**: app bar with the logo (Kameron, `brand`) → date overline + "Last workout yesterday" → **session card** → **week card** ("This week · 2 / 3" + streak chip + week strip) → **last workout card** (history icon, "Pull A · yesterday", "52 min · 18 sets · 1 PR", chevron → Workout detail).
- **States**: `normal`; `after-workout` (next session advanced, week target reached); `in-progress` (Resume banner replaces the card, then an "Up next in Push A" card with the current exercise and set; tap banner → Player); `empty` (first launch: sleep art, "Welcome!", explanation of the loop, big "Create your first session" → Session editor); `pick-session` (bottom sheet "Start another session", note that the pointer follows what you do, session rows with last done; play → Session preview).
- Empty workout → Player with no exercises (list view opens with "Add exercise"). Skip → pointer moves, snackbar with Undo.

### Session preview · `screens-workout.html`
Back, session name, edit (→ Session editor). Meta row. Info line "Changes here apply to this workout only." Exercise rows with drag handles (reorder; swipe/⋮: swap, remove, edit sets). "Add exercise". Sticky bottom bar with big **Start workout**.

### Workout player · `screens-workout.html`, `screens-workout-2.html`
- **Header** 56: close X (→ Leave dialog), session name + "elapsed · ~left" (tabular), **pause**, list view. Below: segmented progress bar, one 4-high segment per exercise (done `success`, current `primary`, skipped `outlineVariant`).
- **Rep-based** (`player_reps`): exercise block (well 96, "EXERCISE 1 / 6" overline, name 24 sp, muscles, "Form cues" expand, "Note" (exercise note), ⋮ = swap / skip / change unit) → personal setup note strip (`secondaryContainer`, pin icon) → set rows with the current set card → "Add set". Footer (`surfaceContainerLow`): "NEXT EXERCISE" + name/plan + thumbnail.
- **Resting** (`player_resting`): "Set 3 · 10 × 40 kg logged" row with Edit, rest timer, controls, next-up card, same footer. Replaces the set list while resting; returns to it on Skip / end.
- **Time-based** (`player_timed`): compact exercise header (well 72), set chips (done value / "Set 2" current / upcoming), timer ring (lead-in → hold), big Stop, helper line. Before Start, the current set card shows Time stepper + Log / Start (see components 2).
- **PR trophy** (`player_trophy`): overlay as in components.
- **Paused** (`player_paused`): blurred surface over the player, 96 circle pause icon, "PAUSED", frozen elapsed time 72 sp, explanation + what's next, big Resume, Finish / Discard text buttons.
- Keep screen on (setting) applies here. Ongoing notification mirrors the rest countdown / "Paused".

### Workout list view · `screens-workout-2.html`
Back (to player), "Push A · exercises", "18:22 · 2 / 6 done", pause. Exercise rows with status + drag handles; current row tinted with ⋮ menu (Go to exercise, Swap, Skip, Change unit, Remove in red). "Add exercise". Sticky big **Finish workout** (→ summary flow). **Swap** opens the picker ("Replacing Overhead press. Sets already logged stay on it.").

### Workout summary · `screens-workout-2.html`
1. If the plan changed: **Update the program?** dialog first (list of changes; skipped exercises are listed but stay in the program).
2. Summary: "WORKOUT COMPLETE" overline, session name, date and time range; 3 tiles (Duration, Sets, Exercises x / y); "New records · n" with PR items (trophy circle, exercise · record type, value + previous); Workout note field; info line "Next session: Legs"; sticky big **Done** → Today.

### Program (tab 2) · `screens-program.html`
Title "Program". "Exercises" entry card (→ catalogue, count). "SESSIONS · LOOP OF 3" + "Drag to reorder". Session rows (tap body → editor, play → preview). Loop note "After Legs, back to Pull A". Extended FAB "Add session".

### Session editor
Back, "Edit session", ⋮ (delete session). Name field. Exercise **cards** (drag handle, well 48, name, one-line summary "4 × 10 · 40 kg · rest 2:00", expand chevron). Expanded card: set table (# · Reps/Time · Load · Unit · ✕), 40-high value boxes ("max" in primary, "Body" grey, "+5"/"−10"), "Add set" (copies last), rest chip "Rest 1:30", delete exercise. Tonal block "Add exercise" (→ picker).

### Exercises (catalogue)
Back, "Exercises". Search ("Search 84 exercises"), chips row (Archived toggle + muscles). Catalogue rows → Exercise detail. Extended FAB "New exercise". No match → empty state with "Create '…'".

### Exercise detail / edit
- **Detail**: back + edit. Full-width image well 240. Name 26 sp, measure ("Reps"/"Time"), muscle chips (primary in `primaryContainer`), description with bullet cues, "My notes / setup" card (editable in place), Progress link card (best + count + sparkline) → Exercise progress.
- **Edit**: close + Save. Photo area 200 (no photo: `add_a_photo` + "the muscle placeholder is shown"), Camera / Gallery buttons. Name, description fields, Measure segmented (Reps / Time), muscle chips (tap 1 = primary filled, 2 = secondary tonal, 3 = off). Bottom: only the action that applies: Delete (never used) or Archive (has history) / Restore (archived).

### Progress (tab 3) · `screens-progress.html`
Title + M3 primary tabs **Calendar · Exercises · History**.
- **Calendar**: calendar month component, streak row, 2 tiles (workouts / time this month). Tap a trained day → Workout detail (or a short list if 2).
- **Exercises**: search, "Sorted by last done · n exercises", rows (well 52, name, "2 days ago · best 42.5 kg", 64×28 sparkline in `chart1`) → Exercise progress.
- **History**: month headers with totals, workout rows (date block 48×52, session name + PR chip count, "52 min · 18 sets", chevron) → Workout detail.

### Exercise progress
Back, exercise name, ⓘ (→ Exercise detail). PR tiles, one per unit (left border in the unit's chart colour). Unit legend chips. Multi-unit chart + range. "All sets · n workouts" grouped by workout: date + session, set pills (unit dot, PR pills yellow with trophy).

### Workout detail
Back, session name, ⋮ (delete workout). Meta (date/time, duration, sets). Workout note card (edit). Per exercise: thumbnail 40, name, ⋮ (exercise note, remove); set lines (number, value, PR chip, edit pencil → edit/delete set). Edits recompute PRs and charts.

### Profile (tab 4) · `screens-profile.html`
Title + gear (→ Settings). Bodyweight card (radius 28: "BODYWEIGHT · TODAY", value 32 sp, change vs last week, sparkline, filled + button → log entry; tap card → Bodyweight). Stat tiles (workouts, time, sets, streak · best, this month vs last for workouts and time). "Latest records": 5 rows (trophy circle, exercise · type, date, value).

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
1. **Main**: Today → Start → Session preview → Start workout → Player (Done) → PR trophy (Nice!) → Resting → list view → ⋮ Swap → picker → list → Finish workout → Update the program? → Summary → Done → Today with the next session advanced.
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
