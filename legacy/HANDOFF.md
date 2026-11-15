# Handoff: My Bodybuilding Program

This file passes context from one Claude session to the next. Each session reads it first and updates it before finishing.

## Project

An Android app (Flutter) to plan and track my training sessions and my progress over time. A first attempt a few years ago was dropped; we are **starting over**. The legacy material is reference only. **The spec is now final (v1.0)** and lives in Notion.

## Session plan

1. **Specifications**: done (this file updated at the end of it).
2. **Design** ← *next*: update the Figma file to match the spec and produce a preview of the app.
3. **App**: build the Flutter Android app in milestones M0–M7 (one branch + PR each), following `CLAUDE.md`, Notion and Figma.

A "master" session coordinates the work and the move from one session to the next.

## Where things are

- **Notion (master spec):** https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30 (§1 Vision, §2 Concepts, §3 Features MVP/Later/Dropped, §4 Screens and navigation, §5 Data model, §6 Sync, §7 Decisions log, §8 Milestones, §9 Open points)
  - Sub-page **Exercise seed (EN)**: 88 translated exercises + PPL program (mirrored in `docs/seed/*.csv`)
- **Figma:** https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program (file key `ut2qBne1bdpEzGoDeNldNK`)
- **`CLAUDE.md`:** stack, architecture, conventions, testing, milestones, "Notion first" rule
- **`README.md`:** summary + links + build placeholders

## Key decisions (details and reasons in Notion §7)

English only · single user · Android/Flutter, sideloaded APK · offline-first with Drift as the source of truth · Firebase (Auth Google, Firestore mirror, Storage later) with optional sign-in in Settings · one phone (cloud = backup/restore, last write wins) · **one program = rotation of sessions** with a "next session" pointer (no fixed weekdays) · per-set logging (reps/seconds, kg, warm-up, failure) + notes · guided workout player + list view · double-progression suggestions that I confirm · kg only (increments 2.5 / 1 kg) · light + dark following the system · **4 tabs: Today · Program · Progress · Settings** · crash-safe workouts (resume prompt) · rest timer notification works with the screen off.

**Dropped:** Music page, random session, manual "max load (2 reps)", fixed weekly split.
**Later:** progress photos, reminders (training day, weigh-in), supersets, media controls, export.

## Brief for the DESIGN session

Goal: turn the existing Figma (old French design, single "Page 1") into the design for spec v1.0, then produce a clickable preview.

1. **Keep the old file as archive:** rename "Page 1" to `Archive (legacy FR)`. Create new pages: `Foundations`, `Components`, `Screens`, `Prototype`.
2. **Foundations (Material 3, light + dark):**
   - Colours from the old app (`legacy/some_previous_app_assets/values/colors.xml`): coral `#F55E42` (primary), light coral `#F68974`, yellow `#FFC854` (accent / PR / trophy), dark grey `#181B1E`, grey `#2D3135`, off-white `#EEEEEE`, white `#FCFCFC`. Build M3 colour roles for both themes and check contrast (WCAG AA), especially white text on coral.
   - Type: **Kameron Bold** for the logo/app name only, **Inter** for everything else (Cantarell and Source Sans Pro are dropped). Fonts are in `legacy/some_fonts/`.
   - Define the tokens as Figma variables (colour, type scale, spacing, radius). The APP session will map them 1:1 to the Flutter theme.
3. **Components:** bottom nav (4 tabs; reuse the old icon style: home, bodybuilder, user→progress, settings), session card, exercise row (thumbnail + name + target), set row (index, previous, kg stepper, reps/sec stepper, warm-up/failure toggles, done check), rest timer (circular countdown, ±15 s, skip), suggestion badge, PR/trophy toast, chart card, calendar month, streak chip, empty states, dialogs, bottom-sheet exercise picker, filter chips.
4. **Screens** (full list and contents in Notion §4), light + dark for each, all text in English:
   Today (normal, workout-in-progress banner, first launch) · Session preview · Workout player (rep-based, time-based, resting, unilateral left/right) · Workout list view · Workout summary (with PRs) · Leave/Resume dialogs · Program · Session editor · Exercise library (+ filters) · Exercise detail/edit · Progress: Overview / Exercises / History / Body · Exercise progress · Workout detail · Settings (signed out / signed in).
5. **Reuse:** exercise illustrations from `legacy/some_images/` (English names in Notion seed `Key` column). 14 exercises have no image: design a muscle-group placeholder (the old `abdominals`, `back_biceps`, `legs`, `pectorals_triceps` images can serve). Use the old Home illustrations (`sleep.png` pillow, `trophy.png`) for empty/rest and PR moments.
6. **UX priorities:** one-handed gym use, large touch targets (≥ 48 dp), one tap to log a set matching the target, readable at arm's length, timer visible from a distance.
7. **Prototype:** main flow Today → Preview → Player (log sets, rest) → Summary → Today (next session advanced), plus Progress → Exercise progress. Share a preview link.
8. If design work reveals a spec gap, **update Notion first** (and note it here).

## Open points (non-blocking)

- Confirm the equipment for *Standing neutral-grip triceps extension* and *Neutral-grip row*.
- "rowing BOM" in the PPL draft was unclear and is mapped to *Barbell row* (Pull B).

## Contents of `legacy/`

| Path | What it is |
|---|---|
| `exercises.xlsx` | ~80 exercises (French). Translated and curated → `docs/seed/exercises.csv` / Notion seed page |
| `program_draft_french.xlsx` | Push / Pull / Legs draft (general / targeted / bodyweight). Translated → `docs/seed/program.csv` |
| `some_images/` | Exercise illustrations + UI icons (`_active` / `_dark_mode` variants), French file names. Mapping in the seed `legacy_image` column |
| `some_fonts/` | Cantarell Bold, Inter Medium, Kameron Bold, Source Sans Pro Regular (only Kameron + Inter kept) |
| `some_previous_app_assets/` | Old Android app leftovers: `drawable*/` images and `values/` (colours, themes, strings) |

## Status

- [x] Repo started, legacy assets imported (master session)
- [x] Specifications: Notion spec v1.0 + seed page, `README.md`, `CLAUDE.md`, `docs/seed/` (specs session, 2026-11-15)
- [ ] Design
- [ ] App (M0–M7)
