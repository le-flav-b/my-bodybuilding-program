"""Convert legacy exercise illustrations to seed images.

Usage (from the repo root):
    python3 -I tools/seed/convert_images.py

Reads PNGs from legacy/some_images/ and writes assets/seed/images/<seed_key>.webp
(max 1080 px on the longest side, transparency kept). Only exercises listed in
SOURCES get an image; the mapping is the record of which old illustration each
seed exercise reuses.
"""

import sys
import unicodedata
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT / "legacy" / "some_images"
OUT_DIR = ROOT / "assets" / "seed" / "images"
MAX_SIDE = 1080
QUALITY = 90

# seed_key -> legacy file name in legacy/some_images/
SOURCES = {
    "barbell_bench_press": "développés_couchés.png",
    "dumbbell_bench_press": "développés_couchés_haltères.png",
    "incline_barbell_bench_press": "développés_inclinés.png",
    "incline_dumbbell_bench_press": "développés_inclinés_haltères.png",
    "dumbbell_fly": "écartés_couchés.png",
    "push_up": "pompes.png",
    "decline_push_up": "pompes_déclinées.png",
    "dumbbell_pullover": "pullover.png",
    "lat_pulldown": "tirage_vertical.png",
    "barbell_row": "rowing.png",
    "dumbbell_row": "rowing_haltère.png",
    "dumbbell_shoulder_press": "overhead_shoulder.png",
    "reverse_fly": "oiseau.png",
    "upright_row": "trapèzes_à_la_barre.png",
    "pike_push_up": "pompes_pike.png",
    "shrug": "dumbbell_shrug.png",
    "barbell_curl": "debout_barre_biceps.png",
    "dumbbell_curl": "haltère.png",
    "hammer_curl": "hammer_curls_debout.png",
    "preacher_curl": "pupitre_barre_droite.png",
    "overhead_triceps_extension": "extensions_verticales_haltères.png",
    "bench_dip": "triceps.png",
    "diamond_push_up": "pompes_diamand.png",
    "wrist_curl": "flexions_poignets_sur_banc.png",
    "crunch": "crunch.png",
    "bicycle_crunch": "crunch_gauche-droite.png",
    "hollow_hold": "jambes_tendues.png",
    "russian_twist": "russian_twist.png",
    "plank": "planche.png",
    "side_plank": "gainage_latéral_droit.png",
    "ab_wheel_rollout": "roue.png",
    "mountain_climber": "mountain_climbers.png",
    "woodchopper": "woodchopper_élastique.png",
    "seated_knee_tuck": "rameur.png",
    "deadlift": "soulevé_de_terre.png",
    "superman": "superman.png",
    "back_squat": "squats.png",
    "leg_extension": "leg_extension.png",
    "lunge": "fentes.png",
    "bulgarian_split_squat": "fentes_bulgares.png",
    "jump_squat": "squats_sautés.png",
    "wall_sit": "chaise.png",
    "leg_curl": "leg_curl.png",
    "standing_calf_raise": "mollets_barre.png",
}


def find(name: str) -> Path:
    """Find a file regardless of Unicode normalisation (NFC vs NFD names)."""
    want = unicodedata.normalize("NFC", name)
    for p in SRC_DIR.iterdir():
        if unicodedata.normalize("NFC", p.name) == want:
            return p
    raise FileNotFoundError(name)


def has_alpha(im: Image.Image) -> bool:
    if im.mode in ("RGBA", "LA") or "transparency" in im.info:
        alpha = im.convert("RGBA").getchannel("A")
        return alpha.getextrema()[0] < 255
    return False


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for key, name in SOURCES.items():
        im = Image.open(find(name))
        im = im.convert("RGBA" if has_alpha(im) else "RGB")
        im.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
        out = OUT_DIR / f"{key}.webp"
        im.save(out, "WEBP", quality=QUALITY, method=6, exact=im.mode == "RGBA")
        print(f"{key}.webp  {im.size[0]}x{im.size[1]}  {im.mode}  {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
