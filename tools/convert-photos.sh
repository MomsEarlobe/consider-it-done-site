#!/usr/bin/env bash
#
# convert-photos.sh — prepare job photos for the website (macOS)
#
# Run this on your Mac; it cannot run in CI or on Linux because it
# uses `sips`, which is macOS-only.
#
#   ./tools/convert-photos.sh <source-folder> <category-slug>
#
# Example:
#   ./tools/convert-photos.sh ~/Desktop/deck-photos decks
#
# Valid category slugs:
#   repairs  painting  masonry  decks  rental-prep  hauling  odd-jobs
#
# What it does, per photo:
#   1. Converts HEIC -> JPEG (and leaves JPG/PNG as-is for step 2)
#   2. Resizes so the longest edge is at most 1600px
#   3. STRIPS ALL EXIF METADATA  <-- important, see below
#   4. Writes a .webp alongside the .jpg when cwebp is available
#
# ---------------------------------------------------------------
#  WHY THE METADATA STRIPPING MATTERS
#  iPhone photos embed GPS coordinates. These are photos of your
#  CUSTOMERS' HOMES. Publishing them unstripped would put the exact
#  street location of your clients' properties on a public website.
#  `sips` does not reliably remove EXIF, so this script uses
#  exiftool when present and refuses to continue quietly if it is
#  missing. Install it with:  brew install exiftool
# ---------------------------------------------------------------

set -euo pipefail

SRC="${1:-}"
CATEGORY="${2:-}"

VALID="repairs painting masonry decks rental-prep hauling odd-jobs"

usage() {
  echo "Usage: $0 <source-folder> <category-slug>"
  echo "Categories: $VALID"
  exit 1
}

[ -z "$SRC" ] && usage
[ -z "$CATEGORY" ] && usage
[ ! -d "$SRC" ] && { echo "ERROR: source folder not found: $SRC"; exit 1; }

if ! echo " $VALID " | grep -q " $CATEGORY "; then
  echo "ERROR: '$CATEGORY' is not a valid category."
  echo "Categories: $VALID"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/assets/work/$CATEGORY"
mkdir -p "$OUT"

# ---- dependency checks -----------------------------------------
if ! command -v sips >/dev/null 2>&1; then
  echo "ERROR: 'sips' not found. This script must run on macOS."
  exit 1
fi

if ! command -v exiftool >/dev/null 2>&1; then
  echo "ERROR: 'exiftool' not found — refusing to run."
  echo
  echo "  These are photos of customers' homes and iPhone images embed"
  echo "  GPS coordinates. Publishing them without stripping metadata"
  echo "  would expose your clients' addresses."
  echo
  echo "  Install it, then re-run:   brew install exiftool"
  exit 1
fi

HAVE_WEBP=0
command -v cwebp >/dev/null 2>&1 && HAVE_WEBP=1
if [ "$HAVE_WEBP" -eq 0 ]; then
  echo "NOTE: 'cwebp' not found — writing JPEG only."
  echo "      For smaller files:  brew install webp"
  echo
fi

MAX_EDGE=1600
JPEG_QUALITY=72   # sips formatOptions: 0-100
WEBP_QUALITY=80

count=0
skipped=0

shopt -s nullglob nocaseglob

for f in "$SRC"/*.{heic,jpg,jpeg,png}; do
  [ -e "$f" ] || continue

  base="$(basename "$f")"
  stem="${base%.*}"

  # slugify: lowercase, non-alphanumerics to dashes, collapse, trim
  slug="$(echo "$stem" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//')"
  [ -z "$slug" ] && slug="photo-$count"

  dest="$OUT/$slug.jpg"

  if [ -e "$dest" ]; then
    echo "  skip (exists): $slug.jpg"
    skipped=$((skipped + 1))
    continue
  fi

  # 1+2. convert to JPEG and resize longest edge
  sips -s format jpeg \
       -s formatOptions "$JPEG_QUALITY" \
       --resampleHeightWidthMax "$MAX_EDGE" \
       "$f" --out "$dest" >/dev/null 2>&1

  # 3. strip ALL metadata (GPS included)
  exiftool -all= -overwrite_original -q -q "$dest"

  # verify the strip actually worked before we call it done
  if exiftool -s -s -s -GPSLatitude "$dest" 2>/dev/null | grep -q .; then
    echo "  !! GPS STILL PRESENT in $slug.jpg — removing output, please investigate"
    rm -f "$dest"
    continue
  fi

  # 4. webp sibling
  if [ "$HAVE_WEBP" -eq 1 ]; then
    cwebp -quiet -q "$WEBP_QUALITY" "$dest" -o "$OUT/$slug.webp"
  fi

  size="$(du -h "$dest" | cut -f1 | tr -d ' ')"
  echo "  ok: $slug.jpg ($size)"
  count=$((count + 1))
done

shopt -u nullglob nocaseglob

echo
echo "Done: $count converted, $skipped skipped -> assets/work/$CATEGORY/"
echo
echo "Next steps:"
echo "  1. Pick a hero image for this category and copy it to:"
echo "       assets/work/$CATEGORY/cover.jpg"
echo "     (cover.jpg is used as the tile image on the homepage and is"
echo "      excluded from the gallery strip so it never shows twice)"
echo "  2. Rename files to describe the job — the filename becomes the"
echo "     caption. e.g. 'front-steps-rebuild.jpg' -> 'Front steps rebuild'"
echo "  3. Rebuild the gallery pages:"
echo "       python3 tools/build-galleries.py"
