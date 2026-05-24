import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("AppViewModel stop / cancel (T7)")
struct StopActiveRunTests {
    /// A mock that sleeps for a configurable duration before returning, so the test
    /// can cancel mid-batch and observe state transitions.
    actor SlowMockRunner: BgBgOneRunning {
        let sleep: Duration
        init(sleep: Duration = .milliseconds(150)) { self.sleep = sleep }
        nonisolated func run(arguments: [String]) async throws -> RunResult {
            try await Task.sleep(for: sleep)
            return RunResult(
                input: URL(fileURLWithPath: arguments.first ?? "/x"),
                output: URL(fileURLWithPath: "/out/x.png"),
                algo: "vn-mask", format: "png", width: 10, height: 10,
                durationMillis: 42
            )
        }
    }

    static func makeVM(runner: any BgBgOneRunning) -> AppViewModel {
        AppViewModel(
            runner: runner,
            scanner: FolderScanner(),
            metaReader: AppViewModelTests.StubMetaReader(),
            bootState: .ready(binary: URL(fileURLWithPath: "/tmp/stub")),
            historyStore: nil
        )
    }

    @Test func primaryActionLabelIdleShowsRemoveBackground() async {
        let vm = Self.makeVM(runner: SlowMockRunner())
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        let label = vm.primaryActionLabel
        #expect(label.contains("Remove background"))
        #expect(!label.contains("Stop"))
    }

    @Test func primaryActionLabelDuringRunShowsStop() async throws {
        let vm = Self.makeVM(runner: SlowMockRunner())
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        vm.startProcessing(ids: Set(vm.files.map(\.id)))
        defer { vm.stopActiveRun() }

        // Wait until at least one item is .processing.
        var spins = 0
        while !vm.files.contains(where: { $0.state == .processing }), spins < 200 {
            try await Task.sleep(for: .milliseconds(5))
            spins += 1
        }
        #expect(vm.primaryActionLabel.lowercased().contains("stop"))
    }

    @Test func stopActiveRunRevertsInFlightToQueued() async throws {
        let vm = Self.makeVM(runner: SlowMockRunner(sleep: .milliseconds(300)))
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        vm.startProcessing(ids: Set(vm.files.map(\.id)))

        var spins = 0
        while !vm.files.contains(where: { $0.state == .processing }), spins < 200 {
            try await Task.sleep(for: .milliseconds(5))
            spins += 1
        }
        vm.stopActiveRun()
        await vm.activeRun?.value

        let stillProcessing = vm.files.contains(where: { $0.state == .processing })
        let anyErrored = vm.files.contains(where: {
            if case .error = $0.state { return true } else { return false }
        })
        #expect(stillProcessing == false)
        #expect(anyErrored == false)
    }
}
