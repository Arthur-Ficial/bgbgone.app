# Releasing bgbgone.app

`make release` is the one-shot command. It runs the full gate:

1. Pre-flight (branch must be `main`, no uncommitted changes, tag must not exist).
2. `swift test`.
3. `swift build -c release` → produce the bundle, embed `bgbgone` into `Contents/Helpers/`, sign with Developer ID, notarise, staple, zip.
4. Post-build verification (`spctl --assess`, `xcrun stapler validate`, helper-present check, plist version check).
5. `git tag` + `git push` + `gh release create` with `.zip` / `SHA256SUMS` / `cask.rb` artefacts.
6. PUT the rendered cask into `Arthur-Ficial/homebrew-tap` via the GitHub API.

## Dry run

Use this **before** every release to verify the artefacts without touching the world:

```bash
DRY_RUN=1 make release
```

Stops right after post-build verification. Leaves `dist/` populated so you can `unzip` the result, run the app, inspect the cask, etc. Nothing in git or GitHub changes.

## One-time setup on a fresh Mac

```bash
# 1. Developer ID Application certificate must be in the login keychain.
security find-identity -v -p codesigning | grep "Developer ID Application"

# 2. Create a notarytool keychain profile (interactive, asks for app-specific password).
xcrun notarytool store-credentials notarytool \
    --apple-id arti.ficial@fullstackoptimization.com \
    --team-id 7D2YX5DQ6M
# (paste the app-specific password from appleid.apple.com when prompted)

# 3. Set `gh` is authed for both Arthur-Ficial/bgbgone.app and Arthur-Ficial/homebrew-tap
gh auth status
```

## Bumping the version

`.version` is the source of truth. Bump it manually before each release:

```bash
$ cat .version
0.1.0
$ echo '0.1.1' > .version
$ git add .version && git commit -m "chore: bump to v0.1.1"
```

Build scripts inject the version into `Info.plist` via PlistBuddy at bundle time.

## Cutting v0.1.0 — the first cut

Once the one-time setup is done and `.version` reads `0.1.0`:

```bash
DRY_RUN=1 make release      # sanity-check artefacts
make release                # the real thing
```

After `make release` succeeds:

- `https://github.com/Arthur-Ficial/bgbgone.app/releases/tag/v0.1.0` is live.
- `brew install Arthur-Ficial/tap/bgbgone-app` works on any Mac with the tap added.
- The Homebrew cask is committed at `Arthur-Ficial/homebrew-tap/Casks/bgbgone-app.rb`.

## Override flags

`SIGN_IDENTITY="..."` — codesign identity (defaults to the project's Developer ID).
`KEYCHAIN_PROFILE="..."` — notarytool profile name (default `notarytool`).
`ENTITLEMENTS="..."` — path to entitlements plist (default `./bgbgone-app.entitlements`).
`DRY_RUN=1` — see above.
