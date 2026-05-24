import Foundation
import Testing
@testable import bgbgone_app

/// End-to-end integration: drop a folder → batch appears → process all → all `.done`.
/// No real Process spawning — `BgBgOneRunning` is mocked.
@MainActor
@Suite("AppViewModel folder → batch → process all")
struct AppViewModelTests {
    // MARK: - Helpers

    static var scanTree: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        return url.appendingPathComponent("fixtures").appendingPathComponent("scan-tree")
    }

    struct InstantRunner: BgBgOneRunning {
        func run(arguments: [String]) async throws -> RunResult {
            let input = URL(fileURLWithPath: arguments.first ?? "/x")
            let out = URL(fileURLWithPath: arguments.dropFirst().drop(while: { $0 != "-o" }).dropFirst().first ?? "/out.png")
            return RunResult(input: input, output: out, algo: "vn-mask", format: "png", width: 1, height: 1, durationMillis: 42)
        }
    }

    struct StubMetaReader: ImageMetaReading {
        func read(_ url: URL) throws -> ImageMeta { ImageMeta(width: 100, height: 100, bytes: 1234) }
    }

    static func makeVM(historyStore: RunHistoryStore? = nil) -> AppViewModel {
        AppViewModel(
            runner: InstantRunner(),
            scanner: FolderScanner(),
            metaReader: StubMetaReader(),
            bootState: .ready(binary: URL(fileURLWithPath: "/tmp/bgbgone-stub")),
            historyStore: historyStore
        )
    }

    // MARK: - Tests

    @Test func droppingFolderCreatesBatchAndPopulatesFiles() async {
        let vm = Self.makeVM()
        #expect(vm.files.isEmpty)
        await vm.handleDrop(urls: [Self.scanTree])

        #expect(vm.files.count == 5) // matches scan-tree fixture image count
        #expect(vm.batches.count == 1)
        #expect(vm.batches[0].imageCount == 5)
        #expect(vm.selectedId == vm.files.first?.id)
    }

    @Test func droppingFolderEndsInSummaryPhase() async throws {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [Self.scanTree])

        // Summary lands synchronously when the scan completes.
        guard case .summary(let summary) = vm.dropMachine.phase else {
            Issue.record("expected .summary, got \(vm.dropMachine.phase)")
            return
        }
        #expect(summary.added == 5)
        #expect(summary.skipped >= 1) // notes.txt at minimum
        #expect(summary.folderName == "scan-tree")
    }

    @Test func processAllMovesAllFilesToDone() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [Self.scanTree])

        await vm.processAll()

        for file in vm.files {
            if case .done = file.state { /* good */ } else {
                Issue.record("file \(file.name) ended in \(file.state)")
            }
        }
        #expect(vm.pendingCount == 0)
    }

    @Test func emptyHandleDropTransitionsSummaryNotCrash() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [])
        if case .summary = vm.dropMachine.phase { /* good */ } else {
            Issue.record("expected .summary after empty drop, got \(vm.dropMachine.phase)")
        }
    }

    @Test func processedFilesCarryRealDurationFromRunner() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [Self.scanTree])
        await vm.processAll()

        for file in vm.files {
            guard case .done(let ms) = file.state else {
                Issue.record("file \(file.name) not done")
                continue
            }
            #expect(ms == 42, "expected the InstantRunner's stamped durationMillis to propagate, got \(ms)")
        }
    }

    @Test func processAllAppendsHistoryEntryPerFile() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppVMHistoryTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RunHistoryStore(directory: dir)

        let vm = Self.makeVM(historyStore: store)
        await vm.handleDrop(urls: [Self.scanTree])
        await vm.processAll()

        for file in vm.files {
            let entries = await store.entries(for: file.id)
            #expect(entries.count == 1, "expected 1 history entry for \(file.name)")
            #expect(entries.first?.outcome == .success)
            #expect(entries.first?.durationMillis == 42)
            #expect(entries.first?.outputURL != nil)
        }
    }

    @Test func processAllIsNoOpWhenBinaryMissing() async {
        let vm = AppViewModel(
            runner: nil,
            scanner: FolderScanner(),
            metaReader: StubMetaReader(),
            bootState: .missingBinary(searched: ["/nowhere"]),
            historyStore: nil
        )
        await vm.handleDrop(urls: [Self.scanTree])
        await vm.processAll()

        // Files are present but no processing happened — no .done, no .processing.
        for file in vm.files {
            switch file.state {
            case .raw: continue
            default: Issue.record("file \(file.name) moved to \(file.state) — runner is nil, should be no-op")
            }
        }
    }
}
