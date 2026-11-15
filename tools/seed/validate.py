"""Validate the catalogue seed.

Usage (from the repo root):
    python3 -I tools/seed/validate.py [path/to/catalogue.json]

Checks assets/seed/catalogue.json against the format in Notion > Technical >
"Seed file format" and that every image in assets/seed/images/ is referenced.
Exits 0 when valid, 1 with a list of errors otherwise. Standard library only.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JSON = ROOT / "assets" / "seed" / "catalogue.json"
KEY_RE = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
MEASURES = {"reps", "time"}
TOP_KEYS = {"version", "muscles", "exercises"}
MUSCLE_KEYS = {"key", "name"}
EXERCISE_KEYS = {
    "key",
    "name",
    "description",
    "measure",
    "primary_muscles",
    "secondary_muscles",
    "image",
}


def non_empty_str(value) -> bool:
    return isinstance(value, str) and value.strip() != ""


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    err = errors.append

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        return [f"cannot read {path}: {e}"]

    if not isinstance(data, dict):
        return ["top level must be an object"]
    if set(data) != TOP_KEYS:
        err(f"top-level keys must be {sorted(TOP_KEYS)}, got {sorted(data)}")
    version = data.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        err("version must be a positive integer")

    # Muscles
    muscles = data.get("muscles")
    muscle_keys: set[str] = set()
    if not isinstance(muscles, list) or not muscles:
        err("muscles must be a non-empty list")
        muscles = []
    for i, m in enumerate(muscles):
        where = f"muscles[{i}]"
        if not isinstance(m, dict):
            err(f"{where}: must be an object")
            continue
        if set(m) != MUSCLE_KEYS:
            err(f"{where}: keys must be {sorted(MUSCLE_KEYS)}, got {sorted(m)}")
        key = m.get("key")
        if not isinstance(key, str) or not KEY_RE.match(key):
            err(f"{where}: invalid key {key!r} (snake_case expected)")
        elif key in muscle_keys:
            err(f"{where}: duplicate muscle key {key!r}")
        else:
            muscle_keys.add(key)
        if not non_empty_str(m.get("name")):
            err(f"{where} ({key}): empty name")

    # Exercises
    exercises = data.get("exercises")
    if not isinstance(exercises, list) or not exercises:
        err("exercises must be a non-empty list")
        exercises = []
    images_dir = path.parent / "images"
    exercise_keys: set[str] = set()
    names: set[str] = set()
    used_images: set[str] = set()
    for i, e in enumerate(exercises):
        if not isinstance(e, dict):
            err(f"exercises[{i}]: must be an object")
            continue
        key = e.get("key")
        where = f"exercises[{i}] ({key})"
        if set(e) != EXERCISE_KEYS:
            err(f"{where}: keys must be {sorted(EXERCISE_KEYS)}, got {sorted(e)}")
        if not isinstance(key, str) or not KEY_RE.match(key):
            err(f"{where}: invalid key (snake_case expected)")
        elif key in exercise_keys:
            err(f"{where}: duplicate exercise key")
        else:
            exercise_keys.add(key)

        name = e.get("name")
        if not non_empty_str(name):
            err(f"{where}: empty name")
        elif name.strip().lower() in names:
            err(f"{where}: duplicate name {name!r}")
        else:
            names.add(name.strip().lower())
        if not non_empty_str(e.get("description")):
            err(f"{where}: empty description")
        if e.get("measure") not in MEASURES:
            err(f"{where}: measure must be one of {sorted(MEASURES)}")

        primary = e.get("primary_muscles")
        secondary = e.get("secondary_muscles")
        for field, value, required in (
            ("primary_muscles", primary, True),
            ("secondary_muscles", secondary, False),
        ):
            if not isinstance(value, list) or (required and not value):
                err(f"{where}: {field} must be a {'non-empty ' if required else ''}list")
                continue
            if len(set(value)) != len(value):
                err(f"{where}: duplicate entries in {field}")
            for mk in value:
                if mk not in muscle_keys:
                    err(f"{where}: {field} references unknown muscle {mk!r}")
        if isinstance(primary, list) and isinstance(secondary, list):
            both = set(primary) & set(secondary)
            if both:
                err(f"{where}: muscles both primary and secondary: {sorted(both)}")

        image = e.get("image")
        if image is not None:
            if not isinstance(image, str) or image != f"{key}.webp":
                err(f"{where}: image must be null or '{key}.webp', got {image!r}")
            elif not (images_dir / image).is_file():
                err(f"{where}: image file missing: {images_dir / image}")
            else:
                used_images.add(image)

    # Every image file must be used
    if images_dir.is_dir():
        for f in sorted(images_dir.iterdir()):
            if f.name.startswith("."):
                continue
            if f.name not in used_images:
                err(f"unused image file: {f}")

    return errors


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_JSON
    errors = validate(path)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        print(f"{len(errors)} error(s) in {path}", file=sys.stderr)
        return 1
    data = json.loads(path.read_text(encoding="utf-8"))
    with_image = sum(1 for e in data["exercises"] if e["image"])
    print(
        f"OK: {path.name} v{data['version']}: {len(data['muscles'])} muscles, "
        f"{len(data['exercises'])} exercises ({with_image} with image)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
