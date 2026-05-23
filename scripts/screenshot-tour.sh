#!/usr/bin/env bash
# screenshot-tour.sh — drive bgbgone-app through its UI states and capture each.
#
# v0.2 captures only the "empty" first-launch state (single screenshot). State-by-state
# fixtures need a BGBGONE_UI_FIXTURE env-var entry-point in the app — landing in a
# follow-up. The harness itself is what M6 ships.
#
# Locally: prefers `peekaboo image --app bgbgone` if available (clean per-window crop);
# falls back to `screencapture -x` (full screen) on hosts that don't have peekaboo
# (e.g. GitHub Actions macos-26 runners).
#
# Outputs into build/screenshots/<state>.png and a manifest.json with timestamp + sha256.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/bgbgone-app.app"
OUT_DIR="$ROOT_DIR/build/screenshots"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "screenshot-tour: $APP_BUNDLE not found — run 'make app' first" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png "$OUT_DIR/manifest.json"

capture_state() {
  local name="$1"; shift
  local out="$OUT_DIR/$name.png"
  echo "screenshot-tour: capturing '$name' → $out"

  if command -v peekaboo >/dev/null 2>&1; then
    if peekaboo image --app bgbgone --path "$out" >/dev/null 2>&1; then
      echo "screenshot-tour: (peekaboo) ok"
      return 0
    fi
    echo "screenshot-tour: peekaboo failed — falling back to screencapture" >&2
  fi

  # Fallback: capture the entire screen. Works on GitHub Actions macOS runners
  # (which have a virtual display) and on local hosts where peekaboo isn't installed.
  if ! screencapture -x "$out" 2>/dev/null; then
    echo "screenshot-tour: screencapture failed for '$name'" >&2
    return 1
  fi
}

quit_app() {
  osascript -e 'tell application "bgbgone-app" to quit' 2>/dev/null || true
  pkill -f "bgbgone-app/Contents/MacOS/bgbgone-app" 2>/dev/null || true
  sleep 1
}

# Make sure no stale instance is up.
quit_app

# State: empty (first launch, no files)
open "$APP_BUNDLE"
sleep 3
osascript -e 'tell application "bgbgone-app" to activate' 2>/dev/null || true
sleep 1
capture_state "empty"
quit_app

# Manifest with sha256 + size for each capture — useful for diffing in CI logs.
echo "{" > "$OUT_DIR/manifest.json"
echo "  \"capturedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$OUT_DIR/manifest.json"
echo "  \"states\": [" >> "$OUT_DIR/manifest.json"
first=1
for png in "$OUT_DIR"/*.png; do
  [[ -f "$png" ]] || continue
  bytes=$(stat -f %z "$png" 2>/dev/null || stat -c %s "$png" 2>/dev/null)
  sha=$(shasum -a 256 "$png" | awk '{print $1}')
  name=$(basename "$png" .png)
  [[ $first -eq 1 ]] || echo "    ," >> "$OUT_DIR/manifest.json"
  first=0
  echo "    { \"state\": \"$name\", \"bytes\": $bytes, \"sha256\": \"$sha\" }" >> "$OUT_DIR/manifest.json"
done
echo "  ]" >> "$OUT_DIR/manifest.json"
echo "}" >> "$OUT_DIR/manifest.json"

echo "screenshot-tour: done — manifest at $OUT_DIR/manifest.json"
