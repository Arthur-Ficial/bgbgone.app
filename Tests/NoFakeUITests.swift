import Foundation
import Testing

/// Source-level enforcement of the no-fake-UI charter (`CLAUDE.md` §"NO FAKE UI"). Scans
/// `Sources/` for tokens that re-introduce the 2026-05-23 fake-app pathology and fails
/// the build if any appear in real code. Comments are stripped before scanning so that
/// the very docs explaining these rules don't trip the check.
@Suite("No fake UI — source-level rule enforcement")
struct NoFakeUITests {
    static var sourcesURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("Sources")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: "/dev/null/Sources")
    }

    /// Walk all `.swift` files under `Sources/` and yield `(url, codeOnlyText)` pairs.
    /// Code-only means: line comments (`// …`) stripped, block comments (`/* … */`)
    /// stripped. Strings are left as-is so that `Text("…")` literals still trigger.
    static func codeOnlySourceTexts() throws -> [(URL, String)] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var out: [(URL, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let raw = try String(contentsOf: url, encoding: .utf8)
            out.append((url, stripComments(raw)))
        }
        return out
    }

    /// Strip Swift comments. Not a full lexer — good enough for grep tests. Handles
    /// `//` to end-of-line and balanced `/* … */` (no nesting depth tracking).
    static func stripComments(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        var inBlock = false
        var inLine = false
        var inString = false
        while i < text.endIndex {
            let c = text[i]
            let next = text.index(after: i) < text.endIndex ? text[text.index(after: i)] : Character(" ")
            if inLine {
                if c == "\n" {
                    inLine = false
                    result.append(c)
                }
                i = text.index(after: i)
                continue
            }
            if inBlock {
                if c == "*" && next == "/" {
                    inBlock = false
                    i = text.index(i, offsetBy: 2)
                } else {
                    if c == "\n" { result.append(c) }
                    i = text.index(after: i)
                }
                continue
            }
            if !inString {
                if c == "/" && next == "/" {
                    inLine = true
                    i = text.index(i, offsetBy: 2)
                    continue
                }
                if c == "/" && next == "*" {
                    inBlock = true
                    i = text.index(i, offsetBy: 2)
                    continue
                }
                if c == "\"" {
                    inString = true
                    result.append(c)
                    i = text.index(after: i)
                    continue
                }
            } else {
                // Crude string handling: end on closing quote unless previous char was \.
                if c == "\"" && text[text.index(before: i)] != "\\" {
                    inString = false
                }
            }
            result.append(c)
            i = text.index(after: i)
        }
        return result
    }

    /// No `Stub*` / `Mock*` / `Fake*` type declarations in `Sources/`. Mocks live in
    /// `Tests/` only.
    @Test func noStubMockFakeTypesInSources() throws {
        let pattern = try Regex(#"\b(?:struct|class|enum|actor|protocol)\s+(?:Stub|Mock|Fake)[A-Z]\w*"#)
        var offenses: [String] = []
        for (url, text) in try Self.codeOnlySourceTexts() {
            for line in text.split(whereSeparator: \.isNewline) {
                if line.contains(pattern) {
                    offenses.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(offenses.isEmpty, "Stub/Mock/Fake types must live in Tests/ only:\n\(offenses.joined(separator: "\n"))")
    }

    /// No aspirational labels that lie about app capability. The 2026-05-23 incident:
    /// `Text("on-device · Vision")` in a codebase forbidden from `import Vision`.
    @Test func noAspirationalLabels() throws {
        let denyList = [
            "on-device · Vision",
            "on-device AI",
            "Powered by Vision",
        ]
        var offenses: [String] = []
        for (url, text) in try Self.codeOnlySourceTexts() {
            for line in text.split(whereSeparator: \.isNewline) {
                for needle in denyList where line.contains(needle) {
                    offenses.append("\(url.lastPathComponent): \(needle)")
                }
            }
        }
        #expect(offenses.isEmpty, "Aspirational labels must not ship — derive UI text from real state:\n\(offenses.joined(separator: "\n"))")
    }

    /// No `.windowStyle(.hiddenTitleBar)` — that modifier is the gateway drug to a
    /// hand-painted fake title bar. Use the real `NSWindow` chrome with `.toolbar`.
    @Test func noHiddenTitleBar() throws {
        var offenses: [String] = []
        for (url, text) in try Self.codeOnlySourceTexts() {
            if text.contains(".windowStyle(.hiddenTitleBar)") {
                offenses.append(url.lastPathComponent)
            }
        }
        #expect(offenses.isEmpty, ".windowStyle(.hiddenTitleBar) hides the real chrome and tempts a fake replacement:\n\(offenses.joined(separator: "\n"))")
    }

    /// No painted-traffic-lights anti-pattern: three Circle().fill calls with the
    /// three macOS title-bar colours within a small window.
    @Test func noPaintedTrafficLights() throws {
        var offenses: [String] = []
        for (url, text) in try Self.codeOnlySourceTexts() {
            let lowered = text.lowercased()
            if lowered.contains("circle().fill") &&
               (lowered.contains("trafficred") || lowered.contains("traffic_red") ||
                lowered.contains(".red") && lowered.contains(".yellow") && lowered.contains(".green")) {
                // Heuristic — only fail if .red AND .yellow AND .green appear close to Circle().fill.
                // We accept some false positives in exchange for clarity. Tighten in v0.3.
                if Self.hasPaintedLightsCluster(in: text) {
                    offenses.append(url.lastPathComponent)
                }
            }
        }
        #expect(offenses.isEmpty, "Hand-painted Circle().fill traffic lights detected — use the real NSWindow chrome:\n\(offenses.joined(separator: "\n"))")
    }

    private static func hasPaintedLightsCluster(in text: String) -> Bool {
        // Look for Circle().fill( within 200 chars of all three colour names.
        guard let r = text.range(of: "Circle().fill") else { return false }
        let window = text[r.lowerBound..<(text.index(r.lowerBound, offsetBy: 400, limitedBy: text.endIndex) ?? text.endIndex)]
        return window.contains(".red") && window.contains(".yellow") && window.contains(".green")
    }

    /// No baked-in demo file references. The 2026-05-23 screenshot showed a
    /// `bronze-tables-OK.png` sample file in the UI — that file lived in the user's
    /// own Pictures, but the *category* (any file path that looks like a sample
    /// committed for demo purposes) must not appear in `Sources/` or `Resources/`.
    @Test func noBakedInDemoFiles() throws {
        let bakedNames = [
            "bronze-tables",
            "sample-image",
            "demo-sample",
            "test-image-1",
        ]
        var offenses: [String] = []
        for (url, text) in try Self.codeOnlySourceTexts() {
            for needle in bakedNames where text.contains(needle) {
                offenses.append("\(url.lastPathComponent) references \(needle)")
            }
        }
        // Also scan Resources/
        let resources = Self.sourcesURL.deletingLastPathComponent().appendingPathComponent("Resources")
        if let enumerator = FileManager.default.enumerator(at: resources, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                for needle in bakedNames where url.lastPathComponent.contains(needle) {
                    offenses.append("Resources/\(url.lastPathComponent) is a baked-in demo file")
                }
            }
        }
        #expect(offenses.isEmpty, "Baked-in demo files are forbidden — Demo Mode downloads to ~/Library/Caches/:\n\(offenses.joined(separator: "\n"))")
    }

    /// v0.3 power-user pass (Epic #33) — every visible label that the tickets specify
    /// must appear verbatim in `Sources/`. If a renaming refactor happens, this catches
    /// it: the ticket text is the SSOT for user-facing copy.
    @Test func v03LiteralLabelsPresent() throws {
        let required: [String] = [
            "Run History",
            "Source Folder",
            "Open Source Folder",
            "Open Output Folder",
            "Process This Only",
            "Undo Process",
            "Redo Process",
            "Select All Visible",
            "Single Files",
            "Mask refinement",
            "Foreground transforms",
            "Background filters",
            "Advanced",
            "Soften edges",
        ]
        var allText = ""
        for (_, text) in try Self.codeOnlySourceTexts() {
            allText += text + "\n"
        }
        var missing: [String] = []
        for label in required where !allText.contains("\"\(label)") {
            missing.append(label)
        }
        #expect(missing.isEmpty, "v0.3 labels missing from Sources/: \(missing.joined(separator: ", "))")
    }

    /// Positive Finder-feel checks: confirm the stock SwiftUI primitives we promised
    /// to use are actually present in `Sources/Views/`.
    @Test func usesStockFinderShapedPrimitives() throws {
        var allText = ""
        for (_, text) in try Self.codeOnlySourceTexts() {
            allText += text + "\n"
        }
        #expect(allText.contains("NavigationSplitView"), "Sources/ must use NavigationSplitView — see CLAUDE.md §'Finder feel'")
        #expect(allText.contains("Table("), "Sources/ must use real Table (not LazyVStack) — see CLAUDE.md §'Finder feel'")
        #expect(allText.contains(".toolbar"), "Sources/ must use real .toolbar (not custom title bar)")
        // Config is now composed from `GroupBox` instead of `Form { Section { ... } }`
        // because macOS 26's `.grouped` Form has noticeably heavy layout overhead
        // that made the Inspector feel sluggish (user feedback 2026-05-24).
        // Both are stock SwiftUI primitives from the Finder-feel charter.
        #expect(allText.contains("GroupBox("), "Sources/ must use real GroupBox for config grouping")
        #expect(allText.contains(".inspector("), "Sources/ should use real .inspector(isPresented:) for the side pane")
        #expect(allText.contains("Picker("), "Sources/ should use real Picker")
    }
}
