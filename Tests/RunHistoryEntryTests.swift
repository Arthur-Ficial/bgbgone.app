import Foundation
import Testing
@testable import bgbgone_app

@Suite("RunHistoryEntry")
struct RunHistoryEntryTests {
    @Test func roundTripsThroughJSON() throws {
        let entry = RunHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 1000),
            finishedAt: Date(timeIntervalSince1970: 1005),
            durationMillis: 5000,
            outputURL: URL(fileURLWithPath: "/tmp/anna_bgbgone.png"),
            outcome: .success,
            configSnapshot: .init(
                outDirectory: URL(fileURLWithPath: "/tmp/cutouts"),
                namePattern: "{name}_bgbgone",
                background: .transparent,
                format: .png,
                filterChain: ""
            )
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(RunHistoryEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test func failureOutcomeCapturesErrorCode() throws {
        let entry = RunHistoryEntry(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 2000),
            finishedAt: Date(timeIntervalSince1970: 2003),
            durationMillis: 3000,
            outputURL: nil,
            outcome: .failure(code: "BGBG_NORESULT_NO_SUBJECT", message: "no subject found"),
            configSnapshot: .init(
                outDirectory: URL(fileURLWithPath: "/tmp/cutouts"),
                namePattern: "{name}_bgbgone",
                background: .transparent,
                format: .png,
                filterChain: ""
            )
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(RunHistoryEntry.self, from: data)
        #expect(decoded == entry)
        if case let .failure(code, message) = decoded.outcome {
            #expect(code == "BGBG_NORESULT_NO_SUBJECT")
            #expect(message == "no subject found")
        } else {
            Issue.record("expected failure outcome")
        }
    }
}
