# Catalogue seed

The pre-filled exercise catalogue the app imports on first launch and after updates.

| File | What |
|---|---|
| `assets/seed/catalogue.json` | Muscles + exercises, format defined in Notion > Technical > "Seed file format" |
| `assets/seed/images/<seed_key>.webp` | Illustrations of seeded exercises (only those that have one) |
| `tools/seed/validate.py` | Checks the JSON and images; exits non-zero on error |
| `tools/seed/convert_images.py` | Converts the legacy PNGs to the seed WebPs (records which old image each exercise reuses) |

Import rules (seed_key, `user_modified`, deleted rows never re-created) are in Notion > Data & Sync > "Pre-filled catalogue (seed)".

## Validate

```bash
python3 -I tools/seed/validate.py
```

It checks:
- unique muscle and exercise keys (snake_case) and unique exercise names
- every muscle referenced by an exercise exists, and no muscle is both primary and secondary
- `measure` is `reps` or `time`
- names and descriptions are not empty
- `image` is `null` or `<key>.webp`, the file exists, and every file in `images/` is used

Standard library only; `convert_images.py` needs Pillow.

## How the seed was made (v1)

- **Scope:** a new list of the main exercises people actually do: gym barbell, dumbbell, machine and cable, plus bodyweight. Obscure moves and pure cardio (burpee, jumping jack, high knees…) are left out.
- **No side variants:** e.g. one "Side plank".
- **Equipment in the name** only where both versions are common and their loads aren't comparable (bench press, incline press, row, curl, shoulder press). Elsewhere names are generic, with optional load ("Lunge", "Shrug").
- **Muscles:** 13 coarse groups: Chest, Back, Shoulders, Traps, Biceps, Triceps, Forearms, Abs (includes obliques), Lower back, Glutes, Quads, Hamstrings, Calves. Traps was added to the usual 12 so shrugs and upright rows have a proper home.
- **Legacy reuse:** when an exercise was in `legacy/exercises.xlsx`, its French description was translated and adapted, and its measure (reps/time) and image were kept. The old defaults (sets, reps, weight, rest) were ignored.
- **Images:** taken from `legacy/some_images/`, which is byte-identical to `legacy/some_previous_app_assets/drawable-v24/`. They were converted to WebP (quality 90, transparency kept, max 1080 px; the sources are ≤ 780 px, so none were resized). Old images that didn't match a standard form of the exercise were not reused (e.g. the straight-bar dip and the plank-position bird dog). The project owner holds the rights to all legacy illustrations.
- **Review:** the list and descriptions were reviewed against the default exercise lists of common workout apps. Safety and clarity fixes and 6 missing staples were added.

## Add an exercise later

1. Add an object to `exercises` in `catalogue.json` with a **new** `key`: snake_case English, never reused. Keys are permanent once shipped; never rename or remove a shipped key.
2. Set `measure` (`reps` or `time`), at least one `primary_muscles` entry and optional `secondary_muscles`, using existing muscle keys. A new muscle goes in `muscles` with a new key.
3. With an illustration: save `assets/seed/images/<key>.webp` (max 1080 px, transparent background, same drawing style) and set `"image": "<key>.webp"`. Without one: `"image": null`. The app then shows the placeholder of the first primary muscle.
4. Changing the content of an already-shipped exercise is allowed: the app updates it only if the user never edited it.
5. Bump `version`, run `python3 -I tools/seed/validate.py`, then commit.

## Exercises still without an image (38)

| Key | Name | Primary muscle (placeholder) |
|---|---|---|
| `machine_chest_press` | Machine chest press | Chest |
| `cable_fly` | Cable fly | Chest |
| `pec_deck` | Pec deck | Chest |
| `dip` | Dip | Chest |
| `pull_up` | Pull-up | Back |
| `chin_up` | Chin-up | Back |
| `seated_cable_row` | Seated cable row | Back |
| `t_bar_row` | T-bar row | Back |
| `inverted_row` | Inverted row | Back |
| `overhead_press` | Overhead press | Shoulders |
| `machine_shoulder_press` | Machine shoulder press | Shoulders |
| `lateral_raise` | Lateral raise | Shoulders |
| `front_raise` | Front raise | Shoulders |
| `face_pull` | Face pull | Shoulders |
| `concentration_curl` | Concentration curl | Biceps |
| `cable_curl` | Cable curl | Biceps |
| `triceps_pushdown` | Triceps pushdown | Triceps |
| `skull_crusher` | Skull crusher | Triceps |
| `close_grip_bench_press` | Close-grip bench press | Triceps |
| `reverse_wrist_curl` | Reverse wrist curl | Forearms |
| `farmers_walk` | Farmer's walk | Forearms |
| `sit_up` | Sit-up | Abs |
| `cable_crunch` | Cable crunch | Abs |
| `hanging_leg_raise` | Hanging leg raise | Abs |
| `lying_leg_raise` | Lying leg raise | Abs |
| `back_extension` | Back extension | Lower back |
| `bird_dog` | Bird dog | Lower back |
| `hip_thrust` | Hip thrust | Glutes |
| `glute_bridge` | Glute bridge | Glutes |
| `hip_abduction` | Hip abduction | Glutes |
| `front_squat` | Front squat | Quads |
| `goblet_squat` | Goblet squat | Quads |
| `bodyweight_squat` | Bodyweight squat | Quads |
| `leg_press` | Leg press | Quads |
| `hack_squat` | Hack squat | Quads |
| `step_up` | Step-up | Quads |
| `romanian_deadlift` | Romanian deadlift | Hamstrings |
| `seated_calf_raise` | Seated calf raise | Calves |
