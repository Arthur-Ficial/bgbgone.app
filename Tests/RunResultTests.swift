import Foundation
import Testing
@testable import bgbgone_app

/// Pins `RunResult`'s decoder to the modern CLI's wrapped envelope. The JSON strings
/// here are verbatim snapshots of real `bgbgone v1.2.23 --json` output (captured from
/// the pinned binary) — NOT a hand-invented shape. The real-binary `RealBinaryE2ETests`
/// remains the ultimate guard that this snapshot still matches the live CLI.
@Suite("RunResult wrapped-envelope decode")
struct RunResultTests {
    /// Verbatim success envelope from `bgbgone v1.2.23 in.jpg -o out.png --format png --json --quiet`.
    static let realEnvelope = #"""
    {"ok":true,"schema":"bgbgone.run.v1","result":{"input":"/in/aldrin-on-moon.jpg","output":"/tmp/out.png","algo":"vn-mask","format":"png","width":1280,"height":1288,"filters":[]}}
    """#

    /// Same shape but with a non-empty `result.filters` array (a `--filter` run).
    static let envelopeWithFilters = #"""
    {"ok":true,"schema":"bgbgone.run.v1","result":{"input":"/in/x.jpg","output":"/tmp/x.png","algo":"person","format":"png","width":640,"height":480,"filters":["mask:feather=8","bg:grayscale"]}}
    """#

    @Test func decodesWrappedEnvelope() throws {
        let r = try JSONDecoder().decode(RunResult.self, from: Data(Self.realEnvelope.utf8))
        #expect(r.input.path == "/in/aldrin-on-moon.jpg")
        #expect(r.output.path == "/tmp/out.png")
        #expect(r.algo == "vn-mask")
        #expect(r.format == "png")
        #expect(r.width == 1280)
        #expect(r.height == 1288)
        #expect(r.filters.isEmpty)
        #expect(r.durationMillis == 0) // not present in JSON; runner stamps it later
    }

    @Test func decodesFiltersArray() throws {
        let r = try JSONDecoder().decode(RunResult.self, from: Data(Self.envelopeWithFilters.utf8))
        #expect(r.algo == "person")
        #expect(r.filters == ["mask:feather=8", "bg:grayscale"])
    }

    /// The OLD flat shape (`{input,…}` with no envelope) must NOT decode — accepting it
    /// silently is exactly the drift that broke real background removal before.
    @Test func rejectsOldFlatShape() {
        let flat = #"{"input":"/in/x.jpg","output":"/tmp/x.png","algo":"vn-mask","format":"png","width":1,"height":1}"#
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(RunResult.self, from: Data(flat.utf8))
        }
    }

    @Test func withDurationStampsElapsedAndKeepsFields() throws {
        let r = try JSONDecoder()
            .decode(RunResult.self, from: Data(Self.envelopeWithFilters.utf8))
            .withDuration(millis: 1234)
        #expect(r.durationMillis == 1234)
        #expect(r.filters == ["mask:feather=8", "bg:grayscale"])
        #expect(r.width == 640)
    }

    @Test func roundTripsThroughEnvelope() throws {
        let original = try JSONDecoder().decode(RunResult.self, from: Data(Self.realEnvelope.utf8))
        let reEncoded = try JSONEncoder().encode(original)
        let again = try JSONDecoder().decode(RunResult.self, from: reEncoded)
        #expect(again == original)
    }
}
