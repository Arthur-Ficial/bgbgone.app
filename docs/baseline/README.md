# Baseline — v0.1.1 forensic evidence (2026-05-23)

These screenshots document the state of `bgbgone-app` immediately before the M1–M8 rewrite. They exist to (a) prove the violations were real, and (b) anchor the before/after pairs in subsequent PRs.

## empty.png — the app-in-an-app

`bgbgone-app` v0.1.1, fresh launch, empty queue. Captured via `screencapture -l <windowID>` of the main 1080×792 NSWindow.

**What it proves:**

1. **Double chrome (app-in-app).** The very top of the image shows the real macOS title bar with real red/yellow/green traffic lights at the left and a system-rendered "bgbgone" title. **Immediately below it**, painted by SwiftUI, sits a *second* title bar with another set of red/yellow/green dots (drawn as `Circle().fill(...)`), the "bgbgone" wordmark centred, and custom-styled "Add files…" / "All done" buttons on the right. This is the **"app-in-an-app"** the user called out — a SwiftUI view pretending to be a window's title bar inside the actual window.
   - Source: `Sources/Views/WindowChrome.swift:8-70` (the whole file) — `TrafficLights` is `HStack { Circle().fill(red) ; Circle().fill(yellow) ; Circle().fill(green) }`.
   - Mounted in: `Sources/App/BgBgOneApp.swift:64-69` inside `mainWindow`.
   - Enabled by: `.windowStyle(.hiddenTitleBar)` at `Sources/App/BgBgOneApp.swift:15` — this hid the real chrome so the fake one could replace it (failed: the real one rendered anyway, hence the double).
   - **What Finder does instead:** uses the system title bar with system traffic lights and a system `.toolbar` for actions (see `finder.png`).

2. **`on-device · Vision` label visible at the bottom-left.** A hardcoded `Text("on-device · Vision")` in a codebase that CLAUDE.md explicitly forbids from `import Vision`. It's a label that **lies about what the app is doing.**
   - Source: `Sources/Views/StatusBar.swift:9`.
   - **What Finder does instead:** Finder's status footer ("N items, X available") is derived from real filesystem state, not aspirational.

3. **Custom-painted button styles** ("Add files…" ghost, "All done" pill). These are `GhostButtonStyle` and `PrimaryButtonStyle` re-implementing `.bordered` / `.borderedProminent`.
   - Source: `Sources/Views/WindowChrome.swift:72-105`.
   - **What Finder does instead:** Finder uses stock `.toolbar` items that automatically pick up the system tint, accent colour, and dark-mode behaviour.

4. **Custom rounded-rectangle window frame with drop shadow.** The whole inner content is wrapped in a `RoundedRectangle` overlay + `.shadow` + `.padding(20)` to simulate a window — because the real window's chrome was hidden by point 1.
   - Source: `Sources/App/BgBgOneApp.swift:37-43`.
   - **What Finder does instead:** uses the system window frame at its natural edge.

## finder.png — the north star

A stock Finder window of `~/dev/bgbgone-tree`, 700×500. This is what the **"Finder, but for background removal"** UI golden goal (now in `CLAUDE.md`) means in practice. M1–M5 must move every state of `bgbgone-app` closer to looking like a member of this family.

**What's stock here that we must inherit:**

- Real system title bar with real traffic lights and real title.
- Real `.toolbar` items (view mode segmented control, sort, group, share, search) — note they live in the title bar, not in a painted strip below it.
- Real sidebar with `.sidebar` material and system-styled rows + system icons.
- Real `Table`-like list (columns: Name / Date Modified / Size / Kind, sortable, multi-select, right-click context menu, Space-bar Quick Look).
- Real system fonts (`.headline`, `.subheadline`, `.callout`) at system sizes.
- Real accent colour (whatever the user has set in System Settings).

## Violations NOT in these screenshots, but committed-evidence elsewhere

| Violation | File:line | Evidence type |
|---|---|---|
| Grey-blob silhouette in place of real image previews | `Sources/Views/DualPreview.swift:57-61, 102-128` | Source comment: *"Subject placeholder — a simple silhouette since we can't decode the image in-process"* — explicit admission |
| `StubMissingRunner` shipping in production code | `Sources/ViewModels/AppViewModel.swift:241-245` | Source — type named `Stub*` in `Sources/` |
| Fake `// ms not tracked in v0.1 — placeholder` timing | `Sources/ViewModels/AppViewModel.swift:220` | Source comment — explicit admission |
| Demo file `bronze-tables-OK.png` visible in user-captured screenshot | (User's screenshot, in conversation) | Visual evidence |

The user's own screenshot in the originating conversation (2026-05-23) captured the grey-blob silhouette + the `bronze-tables-OK.png` sample-file in a single frame — that screenshot is the visual record for those two.

## Next

- M1 deletes `WindowChrome.swift` and rewires to real chrome.
- M2 deletes the silhouette and renders real `NSImage`.
- M3 kills `"on-device · Vision"` + `StubMissingRunner` + the placeholder ms.
- Subsequent milestones in `~/.claude/plans/now-plan-the-path-smooth-hopper.md`.

Each PR posts a before/after pair in its description — the "before" image is one of the above; the "after" is captured fresh from the rewritten app.
