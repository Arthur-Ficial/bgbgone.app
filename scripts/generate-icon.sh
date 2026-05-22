#!/bin/zsh
# generate-icon.sh — render a minimal Resources/AppIcon.icns from a SVG using rsvg + iconutil.
# Placeholder for v0.1: a soft-white rounded square with a checkerboard "removed background" hint.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

mkdir -p "$ROOT_DIR/Resources" "$ICONSET"

# 1024×1024 macOS 26-style app icon:
#   - rounded squircle white tile with a subtle vertical gradient
#   - inner card filled with a checkerboard pattern (= "background removed")
#   - centred blue portrait silhouette (= the subject that survives)
#   - thin scissor-cut accent stripe on the right edge of the subject
# Everything vector. No text — ImageMagick's font lookup is fragile.
SVG="$ROOT_DIR/build/appicon.svg"
cat > "$SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#e9eef6"/>
    </linearGradient>
    <linearGradient id="subject" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3aa6ff"/>
      <stop offset="1" stop-color="#005ec0"/>
    </linearGradient>
    <pattern id="checker" width="64" height="64" patternUnits="userSpaceOnUse">
      <rect width="32" height="32" fill="#d4d9e2"/>
      <rect x="32" width="32" height="32" fill="#ffffff"/>
      <rect y="32" width="32" height="32" fill="#ffffff"/>
      <rect x="32" y="32" width="32" height="32" fill="#d4d9e2"/>
    </pattern>
    <filter id="depth" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="14"/>
      <feOffset dx="0" dy="14"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <!-- outer tile -->
  <rect width="1024" height="1024" rx="224" fill="url(#tile)"/>

  <!-- inner "no background" card -->
  <rect x="144" y="144" width="736" height="736" rx="112" fill="url(#checker)"/>
  <rect x="144" y="144" width="736" height="736" rx="112"
        fill="none" stroke="rgba(0,0,0,0.08)" stroke-width="2"/>

  <!-- portrait silhouette (head + shoulders) on top of the checker -->
  <g filter="url(#depth)">
    <!-- head -->
    <circle cx="512" cy="416" r="148" fill="url(#subject)"/>
    <!-- shoulders / torso -->
    <path d="M 252 880
             L 252 760
             Q 252 596 512 596
             Q 772 596 772 760
             L 772 880 Z"
          fill="url(#subject)"/>
  </g>
</svg>
SVG

# Render via the bundled Swift script — uses Core Graphics directly so we
# don't depend on ImageMagick or RSVG (both fail on complex SVGs anyway).
SCRIPT="$ROOT_DIR/scripts/draw-icon.swift"

for size in 16 32 64 128 256 512 1024; do
    half=$((size / 2))
    swift "$SCRIPT" "$size" "$ICONSET/icon_${size}x${size}.png" >/dev/null
    swift "$SCRIPT" "$size" "$ICONSET/icon_${half}x${half}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
print "==> Generated $ICNS"
