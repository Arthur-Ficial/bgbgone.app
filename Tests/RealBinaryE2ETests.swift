import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import bgbgone_app

/// End-to-end against the REAL bgbgone CLI — no mock. Composes argv through the
/// production `BgBgOneCommand`, spawns the real binary via the production
/// `BgBgOneRunner`, then decodes the output PNG and proves a genuine cutout was
/// produced (both transparent "removed background" and opaque "kept subject"
/// pixels exist). This is the test that catches argv/JSON-envelope drift between
/// the GUI and the evolving CLI — exactly the breakage the mock hid.
///
/// Binary resolution: `BGBGONE_E2E_BINARY` env, else the pinned submodule's freshly
/// built `vendor/bgbgone/.build/release/bgbgone`. Skipped (not failed) when neither
/// is present, so `swift test` stays green on a checkout without the submodule built.
@Suite("Real bgbgone binary e2e")
struct RealBinaryE2ETests {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // …/Tests
            .deletingLastPathComponent() // …/<repo>
    }

    /// The real binary to exercise, or `nil` if unavailable (→ suite is skipped).
    static var binary: URL? {
        let fm = FileManager.default
        if let env = ProcessInfo.processInfo.environment["BGBGONE_E2E_BINARY"] {
            let u = URL(fileURLWithPath: env)
            if fm.isExecutableFile(atPath: u.path) { return u }
        }
        let built = repoRoot.appendingPathComponent("vendor/bgbgone/.build/release/bgbgone")
        return fm.isExecutableFile(atPath: built.path) ? built : nil
    }

    /// Strict public-domain fixture (PD-NASA: Buzz Aldrin on the Moon), shipped with
    /// the pinned submodule — reused here, no duplication or new license bookkeeping.
    static var fixture: URL {
        repoRoot.appendingPathComponent("vendor/bgbgone/Tests/fixtures/aldrin-on-moon.jpg")
    }

    @Test(.enabled(if: RealBinaryE2ETests.binary != nil))
    func realTransparentCutout() async throws {
        let binary = try #require(Self.binary)
        let fixture = Self.fixture
        try #require(FileManager.default.fileExists(atPath: fixture.path),
                     "missing PD fixture: \(fixture.path)")

        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bgbgone-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outDir) }
        let output = outDir.appendingPathComponent("cutout.png")

        // Compose argv through the production type so the fixed `--format` contract
        // is exercised exactly as the running app would emit it.
        let argv = try BgBgOneCommand(
            input: fixture, output: output, background: .transparent, format: .png
        ).arguments()

        let result = try await BgBgOneRunner(binary: binary, timeout: .seconds(120))
            .run(arguments: argv)

        #expect(result.output.path == output.path)
        #expect(result.width > 0 && result.height > 0)
        #expect(FileManager.default.fileExists(atPath: output.path))

        let stats = try #require(Self.alphaStats(of: output), "could not decode output PNG")
        // Dimensions reported in JSON match the actual decoded pixels.
        #expect(stats.width == result.width)
        #expect(stats.height == result.height)
        // A REAL cutout: both fully-transparent (removed background) and fully-opaque
        // (kept subject) pixels exist — not an opaque passthrough or an empty frame.
        #expect(stats.transparent > 0, "no transparent pixels — background was not removed")
        #expect(stats.opaque > 0, "no opaque pixels — subject was not kept")
        let transparentFraction = Double(stats.transparent) / Double(stats.total)
        #expect(transparentFraction > 0.01,
                "transparent area suspiciously small (\(transparentFraction)) — likely not a real cutout")
    }

    // MARK: - Alpha analysis (ImageIO/CoreGraphics is allowed in Tests/, not Sources/)

    /// Decode `url` into RGBA8 and count fully-transparent / fully-opaque pixels.
    static func alphaStats(of url: URL) -> (width: Int, height: Int, transparent: Int, opaque: Int, total: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height
        guard w > 0, h > 0 else { return nil }
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * h)
        let ok: Bool = data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                    data: base, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var transparent = 0, opaque = 0
        var i = 3
        while i < data.count {
            let a = data[i]
            if a == 0 { transparent += 1 } else if a == 255 { opaque += 1 }
            i += 4
        }
        return (w, h, transparent, opaque, w * h)
    }
}
