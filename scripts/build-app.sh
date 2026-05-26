#!/bin/zsh
# build-app.sh — produce build/bgbgone-app.app
#
# Strategy: build the Swift app binary, copy it into the bundle, embed the
# bgbgone CLI helper built from the pinned `vendor/bgbgone` submodule, sign.
# The helper is a declared, version-locked dependency (BGBGONE_VERSION) — not
# whatever happens to be on the dev machine's PATH. Distribution builds set
# SIGN_IDENTITY + KEYCHAIN_PROFILE; dev builds use ad-hoc ("-") signing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="bgbgone-app"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/bgbgone-app.entitlements}"

# The bgbgone CLI version this app build is pinned to and tested against. Must
# match vendor/bgbgone/.version (the submodule is pinned to the v$BGBGONE_VERSION
# tag commit). The embedded binary's --version is asserted against this below.
BGBGONE_VERSION="1.2.23"
SUBMODULE_DIR="$ROOT_DIR/vendor/bgbgone"

# Build (or locate) the version-locked bgbgone helper to embed.
#   1. BGBGONE_HELPER_PATH override — a prebuilt binary (CI cache / cross-build).
#   2. Otherwise build the pinned vendor/bgbgone submodule from source.
# No PATH/Homebrew scavenging: a stale system bgbgone must never end up bundled.
resolve_helper() {
    if [[ -n "${BGBGONE_HELPER_PATH:-}" && -x "${BGBGONE_HELPER_PATH}" ]]; then
        print -- "${BGBGONE_HELPER_PATH}"; return 0
    fi
    # Ensure the submodule is checked out (clean clones / CI without --recursive).
    if [[ ! -f "$SUBMODULE_DIR/.version" ]]; then
        print "==> Initialising vendor/bgbgone submodule" >&2
        git -C "$ROOT_DIR" submodule update --init vendor/bgbgone >&2
    fi
    print "==> Building pinned bgbgone v${BGBGONE_VERSION} from vendor/bgbgone" >&2
    make -C "$SUBMODULE_DIR" build >&2
    local built="$SUBMODULE_DIR/.build/release/bgbgone"
    [[ -x "$built" ]] || { print "error: submodule build did not produce $built" >&2; return 1; }
    print -- "$built"
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

# Bundle Demo Mode assets — the fetch script + manifest live next to the helper.
DEMO_SRC="$ROOT_DIR/scripts"
DEMO_DEST="$APP_BUNDLE/Contents/Resources/scripts"
if [[ -f "$DEMO_SRC/demo-manifest.json" && -f "$DEMO_SRC/fetch-demo-images.sh" ]]; then
    print "==> Bundling Demo Mode assets (manifest + fetch script)"
    mkdir -p "$DEMO_DEST"
    cp "$DEMO_SRC/demo-manifest.json" "$DEMO_DEST/demo-manifest.json"
    cp "$DEMO_SRC/fetch-demo-images.sh" "$DEMO_DEST/fetch-demo-images.sh"
    chmod +x "$DEMO_DEST/fetch-demo-images.sh"
fi

HELPER_PATH="$(resolve_helper)" || {
    print "error: could not build/locate the bgbgone helper — refusing to ship an app without its version-locked CLI dependency" >&2
    exit 1
}
print "==> Embedding bgbgone helper from ${HELPER_PATH}"
cp "$HELPER_PATH" "$APP_BUNDLE/Contents/Helpers/bgbgone"
chmod +x "$APP_BUNDLE/Contents/Helpers/bgbgone"

# Assert the embedded binary is exactly the pinned version. Turns the old
# silent "bundled a stale binary" failure mode into a hard build error.
EMBEDDED_VERSION="$("$APP_BUNDLE/Contents/Helpers/bgbgone" --version 2>/dev/null || true)"
if [[ "$EMBEDDED_VERSION" != *"v${BGBGONE_VERSION}"* ]]; then
    print "error: embedded bgbgone reports '${EMBEDDED_VERSION}', expected v${BGBGONE_VERSION}" >&2
    exit 1
fi
print "==> Verified embedded bgbgone: ${EMBEDDED_VERSION}"

print "==> Signing bundle (${SIGN_IDENTITY})"
sign_bundle

print "==> Built ${APP_BUNDLE}"
