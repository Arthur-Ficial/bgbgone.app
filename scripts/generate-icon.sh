#!/bin/zsh
# generate-icon.sh — render a minimal Resources/AppIcon.icns from a SVG using rsvg + iconutil.
# Placeholder for v0.1: a soft-white rounded square with a checkerboard "removed background" hint.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

mkdir -p "$ROOT_DIR/Resources" "$ICONSET"

# Inline SVG: a 1024×1024 rounded white tile with a 2x2 checker glyph centered
# and a blue accent stripe at the bottom. No text — system-font lookup is
# unreliable across ImageMagick installs.
SVG="$ROOT_DIR/build/appicon.svg"
cat > "$SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <pattern id="c" width="96" height="96" patternUnits="userSpaceOnUse">
      <rect width="48" height="48" fill="#dcdcdc"/>
      <rect x="48" width="48" height="48" fill="#ffffff"/>
      <rect y="48" width="48" height="48" fill="#ffffff"/>
      <rect x="48" y="48" width="48" height="48" fill="#dcdcdc"/>
    </pattern>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#eef2f7"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#g)"/>
  <rect x="160" y="160" width="704" height="704" rx="96" fill="url(#c)"/>
  <rect x="160" y="816" width="704" height="48" rx="24" fill="#007aff"/>
  <circle cx="512" cy="512" r="180" fill="#007aff" opacity="0.92"/>
</svg>
SVG

# Use ImageMagick (`magick`) which is in Homebrew. Falls back to `convert` on
# ImageMagick 6 boxes. SVG → PNG; iconutil packs the result into an .icns.
RENDER() {
    local size="$1" out="$2"
    if command -v magick >/dev/null; then
        magick -background none -density 384 "$SVG" -resize "${size}x${size}" "$out"
    elif command -v convert >/dev/null; then
        convert -background none -density 384 "$SVG" -resize "${size}x${size}" "$out"
    else
        print "ERROR: install ImageMagick (brew install imagemagick)" >&2; exit 1
    fi
}

for size in 16 32 64 128 256 512 1024; do
    half=$((size / 2))
    RENDER "$size" "$ICONSET/icon_${size}x${size}.png"
    RENDER "$size" "$ICONSET/icon_${half}x${half}@2x.png"
done

iconutil -c icns "$ICONSET" -o "$ICNS"
print "==> Generated $ICNS"
