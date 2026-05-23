#!/bin/zsh
# build-app.sh — produce build/bgbgone-app.app
#
# Strategy: build the Swift binary, copy it into the bundle, embed the
# bgbgone CLI helper (PATH → /opt/homebrew/bin → /usr/local/bin), sign.
# Distribution builds set SIGN_IDENTITY + KEYCHAIN_PROFILE; dev builds use
# ad-hoc ("-") signing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="bgbgone-app"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/bgbgone-app.entitlements}"

# Locate the bgbgone helper that build-time should embed.
# Mirrors the runtime BinaryLocator's search order minus the bundled fallback.
resolve_helper() {
    if [[ -n "${BGBGONE_HELPER_PATH:-}" && -x "${BGBGONE_HELPER_PATH}" ]]; then
        print -- "${BGBGONE_HELPER_PATH}"; return 0
    fi
    if command -v bgbgone >/dev/null 2>&1; then
        command -v bgbgone; return 0
    fi
    for p in /opt/homebrew/bin/bgbgone /usr/local/bin/bgbgone; do
        [[ -x "$p" ]] && { print -- "$p"; return 0 }
    done
    return 1
}

codesign_path() {
    local target="$1"; shift || true
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --sign "$SIGN_IDENTITY" "$@" "$target"
    else
        codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$@" "$target"
    fi
}

sign_bundle() {
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true
    if [[ -x "$APP_BUNDLE/Contents/Helpers/bgbgone" ]]; then
        codesign_path "$APP_BUNDLE/Contents/Helpers/bgbgone"
    fi
    if [[ -n "$ENTITLEMENTS" && -f "$ENTITLEMENTS" ]]; then
        codesign_path "$APP_BUNDLE" --entitlements "$ENTITLEMENTS"
    else
        codesign_path "$APP_BUNDLE"
    fi
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

print "==> Building ${APP_NAME} ${VERSION}"
swift build -c release --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/build"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR" --scratch-path "$ROOT_DIR/build")"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Helpers"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

[[ -f "$ICON_SOURCE" ]] && cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

if HELPER_PATH="$(resolve_helper 2>/dev/null)"; then
    print "==> Embedding bgbgone helper from ${HELPER_PATH}"
    cp "$HELPER_PATH" "$APP_BUNDLE/Contents/Helpers/bgbgone"
    chmod +x "$APP_BUNDLE/Contents/Helpers/bgbgone"
else
    print "==> Warning: bgbgone not found — app will only work if user has bgbgone on PATH"
    rmdir "$APP_BUNDLE/Contents/Helpers" 2>/dev/null || true
fi

print "==> Signing bundle (${SIGN_IDENTITY})"
sign_bundle

print "==> Built ${APP_BUNDLE}"
