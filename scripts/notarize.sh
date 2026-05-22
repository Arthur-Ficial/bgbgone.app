#!/bin/zsh
# notarize.sh — submit a .app bundle to Apple notary service and staple the ticket.
# Requires: a `notarytool` keychain profile pre-created via
#   xcrun notarytool store-credentials --apple-id ... --team-id ... --password ...
set -euo pipefail

APP_BUNDLE="${1:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool}"

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
    print "Usage: notarize.sh <path/to/App.app>" >&2; exit 1
fi

ZIP_TMP="$(mktemp -t notarize).zip"
trap 'rm -f "$ZIP_TMP"' EXIT

print "==> Zipping bundle for notarisation"
COPYFILE_DISABLE=1 ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_TMP"

print "==> Submitting to Apple notary (profile=$KEYCHAIN_PROFILE)"
xcrun notarytool submit "$ZIP_TMP" --keychain-profile "$KEYCHAIN_PROFILE" --wait

print "==> Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

print "==> Verifying"
xcrun stapler validate "$APP_BUNDLE"
spctl --assess --type execute "$APP_BUNDLE"
print "==> Notarised + stapled."
