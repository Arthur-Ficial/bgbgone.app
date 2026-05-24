import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("rerunSelectedWithCurrentSettings (T6)")
struct RerunWithCurrentSettingsTests {
    static func makeVM() -> (AppViewModel, RunHistoryStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RerunHistoryTest-\(UUID().uuidString)", isDirectory: true)
        let store = RunHistoryStore(directory: dir)
        let vm = AppViewModel(
            runner: AppViewModelTests.InstantRunner(),
            scanner: FolderScanner(),
            metaReader: AppViewModelTests.StubMetaReader(),
            bootState: .ready(binary: URL(fileURLWithPath: "/tmp/stub")),
            historyStore: store
        )
        return (vm, store, dir)
    }

    @Test func rerunRequeuesDoneFilesAndProcessesAgain() async throws {
        let (vm, store, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        // All files should be done now.
        for f in vm.files {
            guard case .done = f.state else {
                Issue.record("file \(f.name) not done before rerun")
                return
            }
        }
        let firstID = vm.files[0].id
        await vm.rerunSelectedWithCurrentSettings(ids: [firstID])

        guard case .done = vm.files[0].state else {
            Issue.record("file should be .done again after rerun")
            return
        }
        let entries = await store.entries(for: firstID)
        #expect(entries.count == 2, "expected two history entries after rerun")
    }

    @Test func rerunSkipsNonDoneFiles() async {
        let (vm, _, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        // No processAll, so all files are .raw.
        let allIDs = Set(vm.files.map(\.id))
        await vm.rerunSelectedWithCurrentSettings(ids: allIDs)
        for f in vm.files {
            if case .done = f.state {
                Issue.record("rerun should skip non-.done files, but \(f.name) is .done")
            }
        }
    }

    @Test func rerunOnEmptySelectionIsNoOp() async {
        let (vm, _, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        await vm.rerunSelectedWithCurrentSettings(ids: [])
        // No-op — all files should still be .done.
        for f in vm.files {
            guard case .done = f.state else {
                Issue.record("file lost .done state")
                continue
            }
        }
    }
}
