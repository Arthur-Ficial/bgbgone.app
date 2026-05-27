import Foundation
import Testing
@testable import bgbgone_app

/// Exercises `BgBgOneRunner`'s PROCESS handling — exit-code → `RunnerError` mapping,
/// stderr-tail capture, garbage-stdout handling, missing-binary, and cancellation —
/// against a generic `exit-harness.sh` that drives exit code / stderr / delay and
/// CANNOT emit a success envelope. The success wire-contract (argv + `{ok,schema,result}`
/// JSON) is proven separately and only against the real binary in `RealBinaryE2ETests`,
/// so nothing here can give false confidence about it.
@Suite("BgBgOneRunner process & error handling")
struct BgBgOneRunnerTests {
    /// Path to the generic subprocess-behaviour harness (NOT a bgbgone stand-in).
    static var harness: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // …/Tests
        return url.appendingPathComponent("fixtures").appendingPathComponent("exit-harness.sh")
    }

    private static func runner(_ env: [String: String] = [:]) -> BgBgOneRunner {
        BgBgOneRunner(binary: harness, extraEnvironment: env)
    }

    @Test func exitCodeTwoIsNoSubject() async {
        await #expect(throws: RunnerError.noSubject) {
            _ = try await Self.runner(["MOCK_EXIT": "2"])
                .run(arguments: ["/tmp/in.jpg", "-o", "/tmp/out.png"])
        }
    }

    @Test func exitCodeOneIsUserErrorWithStderrTail() async {
        do {
            _ = try await Self.runner(["MOCK_EXIT": "1", "MOCK_STDERR": "bgbgone: --bg argument is malformed"])
                .run(arguments: ["/tmp/in.jpg"])
            Issue.record("expected throw")
        } catch RunnerError.userError(let tail) {
            #expect(tail.contains("malformed"))
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func exitCodeThreeIsFramework() async {
        do {
            _ = try await Self.runner(["MOCK_EXIT": "3", "MOCK_STDERR": "Vision unavailable"])
                .run(arguments: ["/tmp/in.jpg"])
            Issue.record("expected throw")
        } catch RunnerError.framework(let tail) {
            #expect(tail.contains("Vision unavailable"))
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func garbageStdoutOnSuccessIsMalformedJSON() async {
        do {
            // Exit 0 but non-JSON stdout → the runner must surface malformedJSON,
            // never silently "succeed".
            _ = try await Self.runner(["MOCK_STDOUT": "not json at all"])
                .run(arguments: ["/tmp/in.jpg"])
            Issue.record("expected throw")
        } catch RunnerError.malformedJSON {
            // expected
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func nonExecutableBinaryThrows() async {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)")
        let runner = BgBgOneRunner(binary: missing)
        await #expect(throws: RunnerError.binaryNotExecutable(missing)) {
            _ = try await runner.run(arguments: [])
        }
    }

    @Test func cancellationTerminatesProcess() async throws {
        let r = Self.runner(["MOCK_DELAY": "5"])
        let task = Task { try await r.run(arguments: ["/tmp/in.jpg"]) }
        try await Task.sleep(for: .milliseconds(120))
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("expected cancellation throw")
        } catch RunnerError.cancelled, is CancellationError {
            // either is acceptable
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }
}
