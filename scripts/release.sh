#!/bin/zsh
# release.sh — full release pipeline for bgbgone.app.
# Tests → build → sign → notarise → zip → gh release → update Homebrew tap.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="bgbgone-app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
TAG="v${VERSION}"
ARCH="$(uname -m)"
DIST_DIR="$ROOT_DIR/dist"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/bgbgone-app.entitlements}"

print "==> Release $TAG"

BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
[[ "$BRANCH" == "main" ]] || { print "ERROR: not on main (currently: $BRANCH)" >&2; exit 1 }
git -C "$ROOT_DIR" diff-index --quiet HEAD -- || { print "ERROR: uncommitted changes." >&2; exit 1 }
git -C "$ROOT_DIR" tag --list "$TAG" | grep -q "^${TAG}$" \
    && { print "ERROR: Tag $TAG already exists. Bump .version." >&2; exit 1 } || true
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
    || { print "ERROR: No Developer ID Application cert." >&2; exit 1 }

print "==> Tests"
swift test --package-path "$ROOT_DIR"

print "==> Build + sign + notarise + dist"
SIGN_IDENTITY="$SIGN_IDENTITY" KEYCHAIN_PROFILE="$KEYCHAIN_PROFILE" ENTITLEMENTS="$ENTITLEMENTS" \
    "$ROOT_DIR/scripts/build-dist.sh"

APP_ZIP="$DIST_DIR/${APP_NAME}-${TAG}-macos-${ARCH}.zip"
# Stable + versioned ZIPs share the same content; build-dist names the versioned one as v${VERSION}.
[[ -f "$APP_ZIP" ]] || APP_ZIP="$DIST_DIR/${APP_NAME}-v${VERSION}-macos-${ARCH}.zip"

VERIFY_DIR="$(mktemp -d)"
ditto -x -k "$APP_ZIP" "$VERIFY_DIR"
xcrun stapler validate "$VERIFY_DIR/${APP_NAME}.app" >/dev/null 2>&1 \
    || { print "ERROR: notarisation ticket missing." >&2; rm -rf "$VERIFY_DIR"; exit 1 }
rm -rf "$VERIFY_DIR"
print "==> Notarisation verified."

print "==> Tagging $TAG"
git -C "$ROOT_DIR" tag "$TAG"
git -C "$ROOT_DIR" push origin main
git -C "$ROOT_DIR" push origin "$TAG"

print "==> Creating GitHub release"
APP_ZIP_STABLE="$DIST_DIR/${APP_NAME}-macos-${ARCH}.zip"
SHA_FILE="$DIST_DIR/SHA256SUMS"
HOMEBREW_CASK="$DIST_DIR/homebrew/${APP_NAME}.rb"

gh release create "$TAG" \
    --title "${APP_NAME} ${TAG}" \
    --generate-notes \
    "$APP_ZIP" "$APP_ZIP_STABLE" "$SHA_FILE" "$HOMEBREW_CASK"

print "==> Pushing cask to Arthur-Ficial/homebrew-tap"
CASK_B64="$(base64 < "$HOMEBREW_CASK")"
EXISTING_SHA="$(gh api repos/Arthur-Ficial/homebrew-tap/contents/Casks/${APP_NAME}.rb --jq '.sha' 2>/dev/null || true)"
if [[ -n "$EXISTING_SHA" ]]; then
    gh api repos/Arthur-Ficial/homebrew-tap/contents/Casks/${APP_NAME}.rb -X PUT \
        -f message="cask: update ${APP_NAME} to ${TAG}" \
        -f content="$CASK_B64" -f sha="$EXISTING_SHA" --jq '.commit.sha' > /dev/null
else
    gh api repos/Arthur-Ficial/homebrew-tap/contents/Casks/${APP_NAME}.rb -X PUT \
        -f message="cask: add ${APP_NAME} ${TAG}" \
        -f content="$CASK_B64" --jq '.commit.sha' > /dev/null
fi

print "==> Done. https://github.com/Arthur-Ficial/bgbgone.app/releases/tag/$TAG"
