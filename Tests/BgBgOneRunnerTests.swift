import Foundation
import Testing
@testable import bgbgone_app

@Suite("BgBgOneRunner against mock CLI")
struct BgBgOneRunnerTests {
    /// Path to the test fixture shell that mimics the bgbgone CLI's exit codes / stdout.
    static var mockBinary: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // …/Tests
        return url.appendingPathComponent("fixtures").appendingPathComponent("bgbgone-mock.sh")
    }

    private static func runner(_ env: [String: String] = [:]) -> BgBgOneRunner {
        BgBgOneRunner(binary: mockBinary, extraEnvironment: env)
    }

    @Test func happyPathParsesJSON() async throws {
        let result = try await Self.runner().run(
            arguments: ["/tmp/in.jpg", "-o", "/tmp/out.png", "--json", "--quiet"]
        )
        #expect(result.input == URL(fileURLWithPath: "/tmp/in.jpg"))
        #expect(result.output == URL(fileURLWithPath: "/tmp/out.png"))
        #expect(result.algo == "vn-mask")
        #expect(result.format == "png")
        #expect(result.width == 1024)
        #expect(result.height == 768)
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

    @Test func malformedJSONIsFrameworkError() async {
        do {
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
