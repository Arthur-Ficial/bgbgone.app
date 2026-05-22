#!/bin/zsh
# generate-icon.sh — render a minimal Resources/AppIcon.icns from a SVG using rsvg + iconutil.
# Placeholder for v0.1: a soft-white rounded square with a checkerboard "removed background" hint.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

mkdir -p "$ROOT_DIR/Resources" "$ICONSET"

# Inline SVG: a 1024×1024 rounded white tile with a 2x2 checker glyph centered.
SVG="$ROOT_DIR/build/appicon.svg"
cat > "$SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <pattern id="c" width="80" height="80" patternUnits="userSpaceOnUse">
      <rect width="40" height="40" fill="#e6e6e6"/>
      <rect x="40" width="40" height="40" fill="#ffffff"/>
      <rect y="40" width="40" height="40" fill="#ffffff"/>
      <rect x="40" y="40" width="40" height="40" fill="#e6e6e6"/>
    </pattern>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#f0f3f7"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#g)"/>
  <rect x="192" y="192" width="640" height="640" rx="80" fill="url(#c)"/>
  <text x="512" y="912" text-anchor="middle"
        font-family="-apple-system, SF Pro Display, Helvetica, sans-serif"
        font-size="92" font-weight="700" fill="#007aff" letter-spacing="-2">bgbgone</text>
</svg>
SVG

# Need rsvg-convert (brew install librsvg) or fall back to qlmanage.
for size in 16 32 64 128 256 512 1024; do
    half=$((size / 2))
    if command -v rsvg-convert >/dev/null; then
        rsvg-convert -w $size -h $size "$SVG" -o "$ICONSET/icon_${half}x${half}@2x.png" 2>/dev/null || true
        rsvg-convert -w $size -h $size "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
    else
        # Fallback: render via qlmanage at one size and let iconutil resize. Lower-quality but works.
        qlmanage -t -s $size -o "$ICONSET" "$SVG" >/dev/null 2>&1 || true
        mv "$ICONSET/$(basename "$SVG").png" "$ICONSET/icon_${size}x${size}.png" 2>/dev/null || true
    fi
done

iconutil -c icns "$ICONSET" -o "$ICNS"
print "==> Generated $ICNS"
