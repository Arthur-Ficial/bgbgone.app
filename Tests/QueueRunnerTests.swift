import Foundation
import Testing
@testable import bgbgone_app

/// Deterministic in-memory runner. Tracks how many calls are in flight at once so the
/// concurrency-cap assertion can be exact. Each call sleeps for the requested duration
/// (default 30ms) before returning a synthesized RunResult or throwing.
actor MockBgBgOneRunning: BgBgOneRunning {
    var inFlight = 0
    var peakInFlight = 0
    var totalStarted = 0
    var totalCompleted = 0
    let sleep: Duration
    let throwAfter: Int?

    init(sleep: Duration = .milliseconds(30), throwAfter: Int? = nil) {
        self.sleep = sleep
        self.throwAfter = throwAfter
    }

    nonisolated func run(arguments: [String]) async throws -> RunResult {
        await trackStart()
        try await Task.sleep(for: sleep)
        let result = try await trackEnd(arguments: arguments)
        return result
    }

    private func trackStart() {
        inFlight += 1
        totalStarted += 1
        if inFlight > peakInFlight { peakInFlight = inFlight }
    }

    private func trackEnd(arguments: [String]) throws -> RunResult {
        defer { inFlight -= 1; totalCompleted += 1 }
        if let throwAfter, totalCompleted + 1 == throwAfter {
            throw RunnerError.noSubject
        }
        let input = URL(fileURLWithPath: arguments.first ?? "/x")
        return RunResult(
            input: input,
            output: URL(fileURLWithPath: "/out/x.png"),
            algo: "vn-mask", format: "png", width: 10, height: 10
        )
    }
}

@Suite("QueueRunner concurrency + ordering")
struct QueueRunnerTests {
    @Test func respectsConcurrencyCap() async {
        let mock = MockBgBgOneRunning(sleep: .milliseconds(40))
        let queue = QueueRunner(runner: mock, maxConcurrent: 2)
        let items = (0..<6).map { i in
            QueueRunner.WorkItem(id: UUID(), arguments: ["/in/\(i).jpg"])
        }

        await queue.process(items, onStart: { _ in }, onResult: { _, _ in })

        let peak = await mock.peakInFlight
        let total = await mock.totalCompleted
        #expect(peak <= 2)
        #expect(peak == 2) // we have enough items to saturate
        #expect(total == 6)
    }

    @Test func singleWorkerRunsSequentially() async {
        let mock = MockBgBgOneRunning(sleep: .milliseconds(20))
        let queue = QueueRunner(runner: mock, maxConcurrent: 1)
        let items = (0..<4).map { i in
            QueueRunner.WorkItem(id: UUID(), arguments: ["/in/\(i).jpg"])
        }

        await queue.process(items, onStart: { _ in }, onResult: { _, _ in })

        let peak = await mock.peakInFlight
        #expect(peak == 1)
    }

    actor Counter {
        var successes = 0
        var failures = 0
        func recordSuccess() { successes += 1 }
        func recordFailure() { failures += 1 }
    }

    @Test func errorsDoNotStopOthers() async {
        // Throws on the 2nd completion; remaining items must still finish.
        let mock = MockBgBgOneRunning(sleep: .milliseconds(20), throwAfter: 2)
        let queue = QueueRunner(runner: mock, maxConcurrent: 2)
        let items = (0..<4).map { i in
            QueueRunner.WorkItem(id: UUID(), arguments: ["/in/\(i).jpg"])
        }

        let counter = Counter()
        await queue.process(
            items,
            onStart: { _ in },
            onResult: { _, result in
                Task {
                    switch result {
                    case .success: await counter.recordSuccess()
                    case .failure: await counter.recordFailure()
                    }
                }
            }
        )
        // Drain the recording tasks.
        try? await Task.sleep(for: .milliseconds(100))
        let successes = await counter.successes
        let failures = await counter.failures
        // 4 callbacks total. One failure (the throwAfter==2 one), three successes.
        #expect(successes == 3)
        #expect(failures == 1)
    }

    @Test func emptyInputCompletes() async {
        let mock = MockBgBgOneRunning()
        let queue = QueueRunner(runner: mock, maxConcurrent: 2)
        await queue.process([], onStart: { _ in }, onResult: { _, _ in })
        let started = await mock.totalStarted
        #expect(started == 0)
    }
}
