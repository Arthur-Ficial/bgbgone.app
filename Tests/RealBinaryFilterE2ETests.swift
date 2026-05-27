import Foundation
import Testing
@testable import bgbgone_app

/// Every filter the ConfigPanel can compose, exercised against the REAL pinned binary
/// through the production `Config → BgBgOneCommand → BgBgOneRunner` path. This is the
/// regression guard for filter-DSL drift: if the GUI composes a chain the CLI rejects
/// (e.g. the `translate=X:Y` vs `X,Y` bug), the matching case fails here with the CLI's
/// own non-zero exit surfaced as a `RunnerError`. Skipped (not failed) when the pinned
/// submodule binary isn't built — same resolution as `RealBinaryE2ETests`.
@Suite("Real bgbgone binary — every GUI filter chain")
struct RealBinaryFilterE2ETests {
    static var binary: URL? { RealBinaryE2ETests.binary }
    static var fixture: URL { RealBinaryE2ETests.fixture }

    /// One case per ConfigPanel control, each producing exactly the chain that control
    /// emits — composed through the real `Config.effectiveFilterString`, not hand-typed.
    static func cases() -> [FilterCase] {
        func chain(_ mutate: (inout Config) -> Void) -> String {
            var c = Config(outDirectory: FileManager.default.temporaryDirectory)
            mutate(&c)
            return c.effectiveFilterString
        }
        return [
            FilterCase("mask:feather",   chain { $0.maskFeather = 8 }),
            FilterCase("mask:threshold", chain { $0.maskThreshold = 0.5 }),
            FilterCase("mask:expand",    chain { $0.maskExpand = 5 }),
            FilterCase("mask:contract",  chain { $0.maskContract = 3 }),
            FilterCase("fg:scale",       chain { $0.fgScale = 1.2 }),
            FilterCase("fg:translate",   chain { $0.fgTranslateX = 10; $0.fgTranslateY = 20 }),
            FilterCase("fg:rotate",      chain { $0.fgRotate = 45 }),
            FilterCase("fg:flip",        chain { $0.fgFlip = "horizontal" }),
            FilterCase("fg:outline",     chain { $0.fgOutlineColor = "#ffffff"; $0.fgOutlineWidth = 3 }),
            FilterCase("fg:shadow",      chain {
                $0.fgShadowBlur = 8; $0.fgShadowOffsetX = 10; $0.fgShadowOffsetY = 20
                $0.fgShadowOpacity = 0.5; $0.fgShadowColor = "#000000"
            }),
            FilterCase("fg:glow",        chain { $0.fgGlowColor = "#ffffff"; $0.fgGlowRadius = 12; $0.fgGlowIntensity = 0.8 }),
            FilterCase("bg:grayscale",   chain { $0.bgGrayscale = true }),
            FilterCase("bg:blur",        chain { $0.bgBlur = 20 }),
            FilterCase("bg:desaturate",  chain { $0.bgDesaturate = 0.5 }),
        ]
    }

    struct FilterCase: Sendable, CustomStringConvertible {
        let control: String
        let chain: String
        init(_ control: String, _ chain: String) { self.control = control; self.chain = chain }
        var description: String { "\(control) → `\(chain)`" }
    }

    @Test(.enabled(if: RealBinaryFilterE2ETests.binary != nil),
          arguments: RealBinaryFilterE2ETests.cases())
    func guiFilterIsAcceptedAndProducesOutput(_ c: FilterCase) async throws {
        let binary = try #require(Self.binary)
        #expect(!c.chain.isEmpty, "\(c.control): ConfigPanel composed an empty chain")

        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bgbgone-filter-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }
        let output = outDir.appendingPathComponent("out.png")

        // Compose argv exactly as the running app would, then spawn the real binary.
        // A rejected filter exits non-zero → the run THROWS, failing this case with the
        // CLI's own diagnostic — which is precisely how DSL drift gets caught.
        let argv = try BgBgOneCommand(
            input: Self.fixture, output: output,
            background: .transparent, format: .png, filterChain: c.chain
        ).arguments()

        let result = try await BgBgOneRunner(binary: binary, timeout: .seconds(120))
            .run(arguments: argv)

        #expect(result.width > 0 && result.height > 0, "\(c.control): zero-sized result")
        #expect(FileManager.default.fileExists(atPath: output.path),
                "\(c.control): no output file for chain `\(c.chain)`")
    }
}
