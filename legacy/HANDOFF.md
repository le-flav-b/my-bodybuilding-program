# Handoff: My Bodybuilding Program

This file passes context from one Claude session to the next. Each session reads it first and updates it before finishing.

## Project

An Android app (Flutter) to plan my training, guide me through each workout, and track my progress. A first attempt was dropped; we're starting over. `legacy/` is reference material only, not a spec.

## Session plan

1. **Specifications**: done.
2. **Design** ← *next*: design every screen as an HTML preview approved in chat, then write the approved design to Figma.
3. **Catalogue seed** (data task, separate): produce the seed JSON and images in the format defined in Notion > Technical.
4. **App**: milestones M0–M6 (v1.0), then the later items, one branch + PR each, following `CLAUDE.md`, Notion and Figma.

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
  - PRs per unit: heaviest load, most reps, longest hold.
  - Calendar, plus a weekly streak (≥ N workouts per week, default 3).
- **Navigation:** 4 tabs, Today · Program · Progress · Profile. Settings opens from Profile. The exercise catalogue lives inside Program.
- **Profile:** bodyweight log + chart, and stats (totals, streaks, last 5 PRs, this month vs last).
- **Later (after v1.0):** cloud sync (1.1), progress photos (1.2: pose tags, private, linked bodyweight), reminders (1.3), then supersets, media controls and export.
- **Dropped:** music, random session, manual max load, fixed weekly split, progression suggestions, variants, equipment, movement patterns, favourites/hidden, warm-up and failure flags, blocks, phases, several programs.

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
   - Reuse `trophy.png` for PRs and `sleep.png` for empty/rest states.
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

## Status

- [x] Repo started, legacy assets imported (master session)
- [x] Specifications: Notion spec (4 pages + Development database), `README.md`, `CLAUDE.md` (specs session, 2026-11-15)
- [ ] Design
- [ ] Catalogue seed (data task)
- [ ] App (M0–M6 → v1.0)
