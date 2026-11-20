#!/usr/bin/env python3
"""Summarise an lcov file: total line coverage and the domain/ + core/ share.

Usage: python3 -I tools/coverage_summary.py coverage/lcov.info
Generated files (*.g.dart, *.freezed.dart) are ignored.
"""
import sys


def main(path: str) -> int:
    files: dict[str, tuple[int, int]] = {}
    current = None
    found = hit = 0
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line.startswith("SF:"):
                current = line[3:]
                found = hit = 0
            elif line.startswith("DA:"):
                found += 1
                if int(line.split(",")[1]) > 0:
                    hit += 1
            elif line == "end_of_record" and current:
                files[current] = (hit, found)
                current = None

    def keep(name: str) -> bool:
        return not name.endswith((".g.dart", ".freezed.dart"))

    def share(selector) -> tuple[int, int]:
        rows = [v for k, v in files.items() if keep(k) and selector(k)]
        return sum(r[0] for r in rows), sum(r[1] for r in rows)

    def fmt(label: str, pair: tuple[int, int]) -> str:
        hit_lines, total = pair
        pct = 100 * hit_lines / total if total else 0.0
        return f"| {label} | {hit_lines} / {total} | {pct:.1f} % |"

    print("| Scope | Lines | Coverage |")
    print("|---|---|---|")
    print(fmt("All of lib/", share(lambda k: True)))
    print(fmt("domain/ + core/", share(lambda k: "/domain/" in k or "/core/" in k)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "coverage/lcov.info"))
