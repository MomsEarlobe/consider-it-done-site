#!/usr/bin/env bash
#
# import-photos.sh — pull job photos out of Google Drive into the site (macOS)
#
#   ./tools/import-photos.sh
#
# Reads the job folders in
#   06 - Assets, Marketing, and Brand/Photography (Before & After)/
# converts each photo for the web, and drops it into the right
# assets/work/<category>/ folder.
#
# The mapping below is an explicit ALLOWLIST. Anything not named here is
# ignored — including every "DON'T USE" folder, which is never listed and
# so can never be published by accident.
#
# Per photo:
#   1. HEIC/PNG/JPG  ->  JPEG, longest edge 1600px
#   2. ALL EXIF STRIPPED  (iPhone photos embed GPS, and these are pictures
#      of customers' homes — see the exiftool check below)
#   3. named <job-slug>-NN.jpg, which becomes the gallery caption
#
# After running this:
#   python3 tools/build-galleries.py

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRIVE_BASE="$HOME/Library/CloudStorage/GoogleDrive-delayfish2004@gmail.com/My Drive/Work/Personal Work Endeavors/Consider It Done/06 - Assets, Marketing, and Brand/Photography (Before & After)"

MAX_EDGE=1600
JPEG_QUALITY=70

# ── mapping: <category>|<caption slug>|<glob under Photography (Before & After)>
#
# Globs, not literal paths, on purpose: one Drive folder is named
# "Sink/Tub Drain", and a "/" in a Drive folder name does not survive as a
# "/" on the local disk — Drive substitutes a different character. The glob
# matches it whatever it became.
MAPPINGS=(
  "lawn-landscaping|landscaping|Before/Gwen Sorbel/Landscaping"
  "lawn-landscaping|lawn-care|Before/Brooke Olson/Lawn Care"
  "lawn-landscaping|tree-and-branch-cutting|After/Jenesis Rose Long/Branch Cutting"

  "repairs|roof-repair|Before/Brandon Ness/3076 East Bragstad Drive/Roofing"
  "repairs|sink-and-tub-drain|Before/Brandon Ness/3076 East Bragstad Drive/Sink*Drain"
  "repairs|patio-door-weather-sealing|Before/Brandon Ness/3076 East Bragstad Drive/Patio Door Weather Sealing"
  "repairs|stairwell-wall-repair|Before/Brooke Olson/Stair Hall Walls"

  "remodeling|home-remodel|After/Home Remodeling"

  "decks-stonework|deck-stair-build|After/Randy Ust/Deck Stair Building Job"
  "decks-stonework|deck-stairs|Before/Randy Ust/Deck Stairs"
  "decks-stonework|brick-laying|After/Brooke Olson/Brick Laying"
  "decks-stonework|front-brick-re-laying|Before/Brooke Olson/Front Brick Re-laying"

  "hauling|hauling-and-cleanout|After/Gwen Sorbel/Hauling Job"
)

# Loose single files: <category>|<caption slug>|<path>
LOOSE=(
  "repairs|flooring|Before/Flooring.jpeg"
)

# ── dependency checks ────────────────────────────────────────────────
command -v sips >/dev/null 2>&1 || { echo "ERROR: 'sips' not found — macOS only."; exit 1; }

if ! command -v exiftool >/dev/null 2>&1; then
  echo "ERROR: 'exiftool' not found — refusing to run."
  echo
  echo "  iPhone photos embed GPS coordinates and these are pictures of your"
  echo "  CUSTOMERS' HOMES. Publishing them unstripped would put your clients'"
  echo "  street locations on a public website."
  echo
  echo "  Install it, then re-run:   brew install exiftool"
  exit 1
fi

if [ ! -d "$DRIVE_BASE" ]; then
  echo "ERROR: Drive folder not found:"
  echo "  $DRIVE_BASE"
  echo
  echo "Check that Google Drive is mounted, or edit DRIVE_BASE in this script."
  exit 1
fi

# ── convert one file into a category ─────────────────────────────────
convert_one() {   # $1=source  $2=category  $3=slug  $4=index
  local src="$1" cat="$2" slug="$3" idx="$4"
  local outdir="$REPO_ROOT/assets/work/$cat"
  local dest
  dest="$(printf '%s/%s-%02d.jpg' "$outdir" "$slug" "$idx")"

  mkdir -p "$outdir"

  sips -s format jpeg -s formatOptions "$JPEG_QUALITY" \
       --resampleHeightWidthMax "$MAX_EDGE" \
       "$src" --out "$dest" >/dev/null 2>&1 || { echo "    !! convert failed: $(basename "$src")"; return 1; }

  exiftool -all= -overwrite_original -q -q "$dest"

  # verify the strip actually worked before publishing this file
  if exiftool -s -s -s -GPSLatitude "$dest" 2>/dev/null | grep -q .; then
    echo "    !! GPS STILL PRESENT — discarding $(basename "$dest")"
    rm -f "$dest"
    return 1
  fi
  return 0
}

# ── run ──────────────────────────────────────────────────────────────
echo "Source: $DRIVE_BASE"
echo

total=0
declare -a EMPTY_GLOBS=()

for row in "${MAPPINGS[@]}"; do
  IFS='|' read -r cat slug pattern <<< "$row"

  # Resolve the pattern with find -path rather than shell globbing: almost
  # every folder here has a space in its name, and an unquoted glob would be
  # word-split ("Gwen Sorbel" -> "Gwen" + "Sorbel") and match nothing.
  folder="$(find "$DRIVE_BASE" -maxdepth 6 -type d -path "$DRIVE_BASE/$pattern" 2>/dev/null | head -1)"

  if [ -z "$folder" ]; then
    echo "  -- not found, skipped: $pattern"
    EMPTY_GLOBS+=("$pattern")
    continue
  fi

  n=0
  shopt -s nullglob nocaseglob
  for f in "$folder"/*.{heic,jpg,jpeg,png}; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    if convert_one "$f" "$cat" "$slug" "$n"; then
      total=$((total + 1))
    else
      n=$((n - 1))
    fi
  done
  shopt -u nullglob nocaseglob

  echo "  $cat/$slug: $n photo(s)"
done

for row in "${LOOSE[@]}"; do
  IFS='|' read -r cat slug rel <<< "$row"
  src="$DRIVE_BASE/$rel"
  if [ -f "$src" ]; then
    convert_one "$src" "$cat" "$slug" 1 && { total=$((total + 1)); echo "  $cat/$slug: 1 photo"; }
  else
    echo "  -- not found, skipped: $rel"
  fi
done

# ── cover image per category (first photo, copied) ───────────────────
echo
for cat in lawn-landscaping repairs remodeling decks-stonework hauling; do
  dir="$REPO_ROOT/assets/work/$cat"
  [ -d "$dir" ] || continue
  first="$(find "$dir" -maxdepth 1 -name '*.jpg' ! -name 'cover.jpg' | sort | head -1)"
  if [ -n "$first" ]; then
    cp "$first" "$dir/cover.jpg"
    echo "  cover for $cat  <- $(basename "$first")"
  fi
done

echo
echo "Imported $total photo(s)."
if [ "${#EMPTY_GLOBS[@]}" -gt 0 ]; then
  echo
  echo "These folders were not found — check the names in Drive:"
  for g in "${EMPTY_GLOBS[@]}"; do echo "  $g"; done
fi
echo
echo "Next:  python3 tools/build-galleries.py"
