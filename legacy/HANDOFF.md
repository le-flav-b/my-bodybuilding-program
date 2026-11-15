# Handoff — My Bodybuilding Program

This file passes context from one Claude session to the next. Each session reads it first and updates it before finishing.

## Project

An Android app (Flutter) to plan and track my training sessions and my progress over time. A first attempt a few years ago was dropped. We're **starting over**: the old material below is for reference only, not a spec.

## Session plan

1. **Specifications** ← *next*: settle every requirement through back-and-forth, then write it to Notion (master copy), `README.md` and `CLAUDE.md`.
2. **Design**: update the Figma file to match the spec and produce a preview of the app.
3. **App**: build the Flutter Android app in milestones (one branch + PR each), following `CLAUDE.md`, Notion and Figma.

A "master" session coordinates the work and the move from one session to the next.

## Decisions already made

- **Language**: English only. All old material is in French and must be translated (exercise names, descriptions, program names, asset file names once they're used in the app).
- **Users**: just me (single user, no accounts beyond what cloud sync needs).
- **Sync**: data syncs to the cloud, but **everything must work fully offline** (offline-first; sync is a feature, not a requirement for use).
- **Images**: I own the rights to all images in `legacy/`. No licensing or compliance concerns.
- **Source of truth**: Notion holds the full spec. `CLAUDE.md` holds the technical rules and points to Notion and Figma. If a later session changes a spec, it updates Notion first.
- **Cloud backend**: *to be decided during the specs session* (e.g. Firebase vs Supabase vs other).

## Resources

- **Notion**: page "My Bodybuilding Program" (Projects / WIP): https://app.notion.com/p/40481ac8bb2b80f0be49f0e0e814be30
- **Figma**: https://www.figma.com/design/ut2qBne1bdpEzGoDeNldNK/My-Bodybuilding-Program (file key `ut2qBne1bdpEzGoDeNldNK`, currently a single page "Page 1")
- **GitHub**: `le-flav-b/my-bodybuilding-program`

## Contents of `legacy/`

| Path | What it is |
|---|---|
| `exercises.xlsx` | ~80 exercises (French). Columns: `name, image_url, description, default_repetitions, default_time, default_series, default_inter_series_recuperation, default_weight`. An exercise is either rep-based or time-based (`'None'` in the other column). Includes a "rest" pseudo-exercise (`repos`). |
| `program_draft_french.xlsx` | Draft of a Push / Pull / Legs program, split into "general", "targeted" and "bodyweight" exercise groups. |
| `some_images/` | Exercise illustrations + UI icons (bodybuilder, settings, user, edit, close, trophy, sleep…), each with `_active` / `_dark_mode` variants. File names are French; the `#Uxxxx` escapes from the zip were decoded to real accented characters. |
| `some_fonts/` | Cantarell Bold, Inter Medium, Kameron Bold, Source Sans Pro Regular. |
| `some_previous_app_assets/` | Leftovers from the old Android app: `drawable-v24/` images (ASCII names) and `values/` (`colors.xml`, `themes.xml`, `strings.xml`, `dimens.xml`). Useful for the old colour palette. |

## Status

- [x] Repo started, legacy assets imported (master session)
- [ ] Specifications
- [ ] Design
- [ ] App
