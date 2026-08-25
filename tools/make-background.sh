#!/usr/bin/env bash
#
# make-background.sh — build the site background + social share image (macOS)
#
#   ./tools/make-background.sh "/path/to/New Site Background.png"
#
# The source in Google Drive is a 3.08 MB PNG. PNG is the wrong
# container for a photograph, and 3 MB as a page background would
# roughly triple page weight and hurt mobile load badly. This
# produces:
#
#   assets/bg-kitchen.jpg    2000px wide JPEG  (the page background)
#   assets/og-share.jpg      1200x630 JPEG     (Facebook/iMessage previews)
#
# JPEG only, deliberately: the CSS references a single .jpg because
# image-set() picks by format SUPPORT rather than availability, so a
# missing .webp would silently blank the entire site background.
#
# og-share.jpg replaces the old Open Graph image, which pointed at
# assets/Logo.jpeg — the mascot. That mascot has been removed from
# the site, so without this every share would still show it.

set -euo pipefail

SRC="${1:-}"

[ -z "$SRC" ] && { echo "Usage: $0 \"/path/to/New Site Background.png\""; exit 1; }
[ ! -f "$SRC" ] && { echo "ERROR: file not found: $SRC"; exit 1; }

command -v sips >/dev/null 2>&1 || { echo "ERROR: 'sips' not found — macOS only."; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/assets"
mkdir -p "$OUT"

echo "Source: $SRC"
echo

# --- main background: step down until it fits the budget ---------------
# This photo is only ever seen through a scrim at 72-94% opacity, so heavy
# JPEG compression is invisible on it while the byte savings are not. Rather
# than make someone hand-tune a quality number, walk down the ladder (and
# then the width) until the file is under budget.
TARGET_KB=400
kb_of() { echo $(( $(stat -f%z "$1") / 1024 )); }

chosen_q=""; chosen_w=""
for w in 2000 1700; do
  for q in 78 66 56 46 38; do
    sips -s format jpeg -s formatOptions "$q" \
         --resampleWidth "$w" \
         "$SRC" --out "$OUT/bg-kitchen.jpg" >/dev/null 2>&1
    if [ "$(kb_of "$OUT/bg-kitchen.jpg")" -le "$TARGET_KB" ]; then
      chosen_q="$q"; chosen_w="$w"; break 2
    fi
  done
done

command -v exiftool >/dev/null 2>&1 && exiftool -all= -overwrite_original -q -q "$OUT/bg-kitchen.jpg"

if [ -n "$chosen_q" ]; then
  echo "  bg-kitchen.jpg   $(kb_of "$OUT/bg-kitchen.jpg")K  (quality $chosen_q, ${chosen_w}px wide)"
else
  echo "  bg-kitchen.jpg   $(kb_of "$OUT/bg-kitchen.jpg")K  ** still over ${TARGET_KB}K **"
  echo "                   The source may be unusually detailed; consider cropping it."
fi

# --- social share image, 1200x630 ---
# sips has no smart crop: resample to cover, then crop to exact size.
sips -s format jpeg -s formatOptions 82 \
     --resampleHeightWidthMax 1400 \
     "$SRC" --out "$OUT/og-share.jpg" >/dev/null 2>&1
sips -c 630 1200 "$OUT/og-share.jpg" >/dev/null 2>&1
command -v exiftool >/dev/null 2>&1 && exiftool -all= -overwrite_original -q -q "$OUT/og-share.jpg"
echo "  og-share.jpg     $(du -h "$OUT/og-share.jpg" | cut -f1 | tr -d ' ')"

echo
echo "Done — the CSS already points at these files. Open index.html to check."
