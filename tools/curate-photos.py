#!/usr/bin/env python3
"""
Apply tools/photo-index.tsv to assets/work/.

import-photos.sh names files after Drive folders; this step decides what
actually ships, which category it lands in, and what the caption says.

    python3 tools/curate-photos.py            # apply
    python3 tools/curate-photos.py --dry-run  # show what would happen

Nothing is ever deleted: dropped photos move to assets/work/_unused/, which
build-galleries.py ignores because it is not one of the five categories.

Run order:
    ./tools/import-photos.sh
    python3 tools/curate-photos.py
    python3 tools/build-galleries.py
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "assets" / "work"
INDEX = Path(__file__).resolve().parent / "photo-index.tsv"
UNUSED = WORK / "_unused"

DRY = "--dry-run" in sys.argv


def load_index():
    rows = []
    for lineno, raw in enumerate(INDEX.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in raw.split("\t") if p.strip() != ""]
        if len(parts) < 4:
            print(f"  !! line {lineno}: expected at least 4 tab-separated fields, got {len(parts)}")
            continue
        source, action, category, new_name = parts[0], parts[1], parts[2], parts[3]
        if action not in ("keep", "drop", "cover"):
            print(f"  !! line {lineno}: unknown action {action!r}")
            continue
        rows.append((source, action, category, new_name))
    return rows


def main():
    if not INDEX.is_file():
        print(f"ERROR: {INDEX} not found")
        return 1

    rows = load_index()
    planned = {}          # destination path -> source path
    covers = {}           # category -> destination path
    drops = []
    missing = []

    for source, action, category, new_name in rows:
        src = WORK / source
        if not src.is_file():
            missing.append(source)
            continue
        if action == "drop":
            drops.append(src)
            continue
        dest = WORK / category / f"{new_name}{src.suffix}"
        if dest in planned:
            print(f"  !! two photos both map to {category}/{dest.name} — check the index")
            continue
        planned[dest] = src
        if action == "cover":
            covers[category] = dest

    # stage first so a rename never overwrites a file another row still needs
    staging = WORK / "_staging"
    if not DRY:
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True)

    for dest, src in planned.items():
        tmp = staging / f"{dest.parent.name}__{dest.name}"
        print(f"  keep  {src.relative_to(WORK)}  ->  {dest.relative_to(WORK)}")
        if not DRY:
            shutil.copy2(src, tmp)

    for src in drops:
        print(f"  drop  {src.relative_to(WORK)}  ->  _unused/{src.name}")
        if not DRY:
            UNUSED.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, UNUSED / src.name)

    if DRY:
        for m in missing:
            print(f"  -- missing, skipped: {m}")
        print(f"\nDRY RUN — {len(planned)} kept, {len(drops)} dropped, {len(missing)} missing")
        return 0

    # clear the five category folders, then lay down the curated set
    categories = {d.parent.name for d in planned} | set(covers)
    for cat in categories:
        for f in (WORK / cat).glob("*.jpg"):
            f.unlink()

    for dest in planned:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(staging / f"{dest.parent.name}__{dest.name}"), str(dest))

    for cat, dest in covers.items():
        shutil.copy2(dest, WORK / cat / "cover.jpg")
        print(f"  cover {cat}  <-  {dest.name}")

    shutil.rmtree(staging)

    for m in missing:
        print(f"  -- missing, skipped: {m}")

    print(f"\n{len(planned)} kept, {len(drops)} moved to _unused, {len(missing)} missing.")
    for cat in sorted(categories):
        n = len(list((WORK / cat).glob("*.jpg"))) - 1   # minus cover.jpg
        print(f"  {cat}: {n} photo(s)")
    print("\nNext:  python3 tools/build-galleries.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
