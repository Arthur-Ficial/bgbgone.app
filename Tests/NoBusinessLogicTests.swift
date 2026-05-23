import Foundation
import Testing

/// The hardest rule in the repo: bgbgone-app must never re-implement image-processing.
/// All segmentation/matting/compositing belongs to the spawned `bgbgone` CLI binary.
///
/// This test scans `Sources/` for forbidden framework imports. If it ever passes a
/// release that imports any of these, the GUI has secretly grown business logic
/// and the architectural promise is broken.
@Suite("No business logic")
struct NoBusinessLogicTests {
    /// Frameworks that could segment, matte, composite, or otherwise replicate `bgbgone`'s job.
    /// `SwiftUI`, `AppKit`, `Foundation`, `ImageIO` (metadata-only) and `os` are explicitly OK.
    static let forbiddenImports: [String] = [
        "Vision",
        "CoreImage",
        "CoreML",
        "Metal",
        "MetalKit",
        "Accelerate",
        "MetalPerformanceShaders",
        "VideoToolbox",
    ]

    /// Walks `Sources/` and asserts that none of `forbiddenImports` ever appears as `import X`.
    @Test func noForbiddenImportsAnywhereInSources() throws {
        let sourcesURL = Self.repoRoot.appendingPathComponent("Sources", isDirectory: true)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) else {
            Issue.record("Could not enumerate Sources/ at \(sourcesURL.path)")
            return
        }

        var offenses: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let importedModule = trimmed
                    .replacingOccurrences(of: "import ", with: "")
                    .split(separator: " ").first.map(String.init) ?? ""
                if Self.forbiddenImports.contains(importedModule) {
                    offenses.append("\(url.lastPathComponent): import \(importedModule)")
                }
            }
        }

        #expect(offenses.isEmpty,
                "Forbidden imports found — bgbgone-app must not do image processing in-process:\n\(offenses.joined(separator: "\n"))")
    }

    /// Resolve the repo root from the test bundle's location.
    /// `swift test` runs from `.build/<config>/<package>PackageTests.xctest`; walking up
    /// until we find `Package.swift` is the most portable way to locate `Sources/`.
    static var repoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
