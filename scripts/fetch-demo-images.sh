#!/usr/bin/env bash
# fetch-demo-images.sh — download the 10 Demo Mode images from Wikimedia Commons
# into the app's per-user cache. Idempotent (skips files that already exist with
# the expected size). Loud failures — no fake fallbacks.
#
# Invoked by:
#   - The GUI's "Try Demo" flow (via NSTask → bash → this script).
#   - The user, manually, with no args.
#
# Exit codes:
#   0  — all images present (downloaded fresh or already cached)
#   1  — usage / environment error
#   2  — one or more downloads failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/demo-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "fetch-demo-images: manifest not found at $MANIFEST" >&2
  exit 1
fi

CACHE_DIR="${BGBGONE_DEMO_CACHE_DIR:-$HOME/Library/Caches/bgbgone-app/demo}"
mkdir -p "$CACHE_DIR"

USER_AGENT="bgbgone-app/0.2 (https://github.com/Arthur-Ficial/bgbgone-app; demo-mode-fetch)"

# Parse manifest entries: filename<TAB>url per line. Pure jq, no Python dep.
if ! command -v jq >/dev/null 2>&1; then
  echo "fetch-demo-images: jq is required (brew install jq)" >&2
  exit 1
fi

entries="$(jq -r '.images[] | "\(.filename)\t\(.url)"' "$MANIFEST")"

ok=0
fail=0
already=0
fail_list=()

while IFS=$'\t' read -r filename url; do
  [[ -z "$filename" ]] && continue
  dest="$CACHE_DIR/$filename"

  if [[ -s "$dest" ]]; then
    echo "demo: ✓ $filename (cached)"
    already=$((already + 1))
    continue
  fi

  echo "demo: ↓ $filename ← $url"
  if curl --fail --silent --show-error --location \
       --user-agent "$USER_AGENT" \
       --output "$dest.partial" \
       "$url"; then
    mv "$dest.partial" "$dest"
    bytes=$(stat -f %z "$dest" 2>/dev/null || stat -c %s "$dest" 2>/dev/null)
    sha=$(shasum -a 256 "$dest" | awk '{print $1}')
    echo "demo:    $bytes bytes  sha256=$sha"
    ok=$((ok + 1))
  else
    echo "demo: ✗ $filename failed" >&2
    rm -f "$dest.partial"
    fail=$((fail + 1))
    fail_list+=("$filename")
  fi
done <<< "$entries"

echo "demo: done — $ok downloaded, $already cached, $fail failed"

if [[ $fail -gt 0 ]]; then
  echo "demo: failed entries: ${fail_list[*]}" >&2
  exit 2
fi

# Print the cache dir so the GUI can read it from stdout's last line.
echo "$CACHE_DIR"
