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

# --- main background, 2000px wide JPEG ---
sips -s format jpeg -s formatOptions 78 \
     --resampleWidth 2000 \
     "$SRC" --out "$OUT/bg-kitchen.jpg" >/dev/null 2>&1
command -v exiftool >/dev/null 2>&1 && exiftool -all= -overwrite_original -q -q "$OUT/bg-kitchen.jpg"
echo "  bg-kitchen.jpg   $(du -h "$OUT/bg-kitchen.jpg" | cut -f1 | tr -d ' ')"

# --- social share image, 1200x630 ---
# sips has no smart crop: resample to cover, then crop to exact size.
sips -s format jpeg -s formatOptions 82 \
     --resampleHeightWidthMax 1400 \
     "$SRC" --out "$OUT/og-share.jpg" >/dev/null 2>&1
sips -c 630 1200 "$OUT/og-share.jpg" >/dev/null 2>&1
command -v exiftool >/dev/null 2>&1 && exiftool -all= -overwrite_original -q -q "$OUT/og-share.jpg"
echo "  og-share.jpg     $(du -h "$OUT/og-share.jpg" | cut -f1 | tr -d ' ')"

echo
echo "Budget check — bg-kitchen.jpg should be under ~400 KB."
echo "If it is larger, lower the quality: edit formatOptions 78 in this script."
echo
echo "Then rebuild nothing else — the CSS already points at these files."
