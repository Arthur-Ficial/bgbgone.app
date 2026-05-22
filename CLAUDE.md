# bgbgone.app — project instructions

> **`bgbgone.app` is to `bgbgone` what `apfel-chat` is to `apfel`.** All scaffolding, scripts, and conventions from [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) apply here unless explicitly overridden.

## Golden Goal

> Drop a folder. Watch it process. End up with a folder of clean cutouts. Never touch a terminal.

## NO BUSINESS LOGIC · NO FALLBACKS · NO HALF-FEATURES

This is the hardest rule in the repo. **Every pixel-level operation belongs to the spawned `bgbgone` CLI binary.** The Swift code here is allowed to:

- Read **only** image metadata via `ImageIO` (`width × height × bytes` for the file list).
- Resolve `bgbgone` binary path via `BinaryLocator` (PATH first, embedded fallback).
- Compose `[String]` argv from `Config + ImageFile` via `BgBgOneCommand`.
- Spawn `Process`, read stdout JSON, read exit code, surface to ViewModel.
- Walk folders with `FileManager` / `NSDirectoryEnumerator`.
- Render SwiftUI views from state.

It is **not** allowed to:

- `import Vision`, `import CoreImage`, `import CoreML`, `import Metal`, `import Accelerate`, or any other framework that could do image segmentation, matting, or compositing in-process. **A test (`NoVisionImportTest`) scans `Sources/` and fails if any of these appear.**
- Re-implement matting, alpha blending, format conversion, or background compositing.
- Fall back to a "simpler algorithm" if `bgbgone` is missing. If the binary cannot be found (which should be impossible thanks to the embedded fallback), the app shows `MissingBinaryView` and disables actions.
- Parse `bgbgone`'s human-readable stderr text. Use `--json` / `--ndjson` only.

If a feature needs new image-processing capability, **add it to `bgbgone` first**, then surface the new flag in the GUI's `Config + BgBgOneCommand`. Never the other way around.

## Ownership & autonomy

Arthur is authorised to commit, tag, push, cut releases, and update the Homebrew cask formula directly — provided the quality bar below is green.

Quality bar (all green before pushing to `main` or tagging a release):

- `make test` passes (every unit and integration test).
- `make app` produces a launchable bundle that opens to the empty state without errors.
- `make release` runs the full gate: bump, build, test, dist, notarize, gh release create, render cask, push to `Arthur-Ficial/homebrew-tap`.
- Every UI state in `design/project/bgbgone.html` has a matching Swift screen, visually verified.
- No `import Vision|CoreImage|Metal|Accelerate|CoreML` anywhere under `Sources/`.

External communication (emails, PRs to other projects, posts) still needs Franz's explicit approval — only the local repo work is autonomous.

## Tech baseline — modern only

Target the bleeding edge of what the user's machine runs today (macOS 26, Apple Silicon, Swift 6.3 toolchain). Concretely:

- **Swift 6.3+**, complete strict concurrency. Don't add `@preconcurrency` to silence warnings unless the suppressed warning is actually impossible to fix.
- **`@Observable`** (Observation framework) for ViewModels — never the legacy `ObservableObject` / `@Published` pair.
- **`async`/`await` + `AsyncStream`** for all I/O. Do not use Combine, completion handlers, or NotificationCenter for new code.
- **Swift Testing only**, no XCTest. (`swift-testing` ≥ 0.99; once Swift 6.4 lands and ships Testing in-toolchain, drop the explicit package dep.)
- **SwiftUI** on macOS 26 APIs — `NavigationStack` (never `NavigationView`), `.scrollContentBackground`, `WindowGroup` + `.windowResizability(.contentSize)`, `.onDrop(of:isTargeted:perform:)`, etc.
- **Foundation modern types** — `URL` everywhere (no `String` paths), `Duration`, `Date.now`, `ContinuousClock`.
- **No third-party deps for problems Foundation/SwiftUI solve.** No SnapKit, no Alamofire, no third-party JSON. Resist hard.
- **Strict concurrency Sendable** — Models are `Sendable` value types where possible.

If a "modern" choice forces a hack (e.g. a SwiftUI API has a known bug on macOS 26 you actually hit), document the workaround in a comment with the rdar/forum link and revisit when the platform fixes it.

## Architecture (apfel-chat pattern)

```
Sources/
├── App/        @main, BinaryLocator, BuildInfo
├── Models/     ImageFile, Batch, ProcessingState, DropPhase, DragHint, Config, BgBgOneCommand
├── Protocols/  BgBgOneRunning, FolderScanning, ImageMetaReading
├── Services/   BgBgOneRunner (Process), FolderScanner, ImageMetaReader (ImageIO)
├── ViewModels/ AppViewModel (state), DropMachine (pure FSM), QueueRunner (bounded concurrency)
└── Views/      WindowChrome, DualPreview, SelectedMeta, ConfigPanel, FileListView,
                StatusBar, DropVeil, IngestOverlay, DropSummary, MissingBinaryView
Tests/          Mirrors Sources/. swift-testing only. TDD: test before impl.
```

Every Service has a Protocol so it can be mocked in tests. Views render state and emit intents; ViewModels own state machines; Services do I/O.

## Build & test

```bash
make test               # swift test
make build              # swift build -c release
make app                # build + bundle + sign (ad-hoc by default)
make run                # open the bundle
make dist               # zip + sha256
make release            # full release pipeline (Arthur only)
```

`.version` is the single source of truth for the version number. Build scripts inject it into `Info.plist` via PlistBuddy at bundle time. Same pattern as `bgbgone` and `apfel-chat`.

## Design reference (this is the spec)

`design/project/bgbgone.html` (open in a browser) is **the spec** for layout, color, copy, and interaction. The Tweaks panel cycles through every drop phase. Any Swift screen must match its HTML counterpart pixel-for-pixel — drift > 3% is a release blocker.

`design/chats/chat1.md` and `chat2.md` capture the design intent in the user's own words. Read them when in doubt about *why* the UI is shaped this way.

## Key files

| Area | Files |
|------|-------|
| Entry point | `Sources/App/BgBgOneApp.swift` |
| Binary discovery | `Sources/App/BinaryLocator.swift` |
| CLI argv composer | `Sources/Models/BgBgOneCommand.swift` |
| Process spawn | `Sources/Services/BgBgOneRunner.swift` |
| Drop FSM | `Sources/ViewModels/DropMachine.swift` |
| Queue executor | `Sources/ViewModels/QueueRunner.swift` |
| Design spec | `design/project/bgbgone.html` |
| Version | `.version` |
| Bundle metadata | `Info.plist` |
| Entitlements | `bgbgone-app.entitlements` |
| Tests | `Tests/` |
