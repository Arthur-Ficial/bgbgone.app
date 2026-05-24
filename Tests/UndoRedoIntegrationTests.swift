import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("Undo/Redo end-to-end (T8)")
struct UndoRedoIntegrationTests {
    static func makeVM() -> (AppViewModel, RunHistoryStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UndoRedoTests-\(UUID().uuidString)", isDirectory: true)
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

    @Test func processAllRegistersUndoEntry() async {
        let (vm, _, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        #expect(vm.undoManager.canUndo == true)
        #expect(vm.undoManager.undoLabel.contains("Undo Process"))
    }

    @Test func undoRevertsDoneFilesToRaw() async {
        let (vm, _, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        await vm.undoLastRun()
        for f in vm.files {
            #expect(f.state == .raw, "file \(f.name) should be .raw after undo, got \(f.state)")
        }
        #expect(vm.undoManager.canRedo == true)
    }

    @Test func redoRestoresFilesToDone() async {
        let (vm, _, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        await vm.undoLastRun()
        await vm.redoLastRun()
        for f in vm.files {
            guard case .done = f.state else {
                Issue.record("file \(f.name) should be .done after redo")
                continue
            }
        }
    }

    @Test func redoUsesSnapshotConfigNotCurrent() async {
        let (vm, store, dir) = Self.makeVM()
        defer { try? FileManager.default.removeItem(at: dir) }
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        // Set output dir A, process.
        vm.config.outDirectory = URL(fileURLWithPath: "/tmp/out-A", isDirectory: true)
        await vm.processAll()
        let firstID = vm.files[0].id
        // Change output dir to B.
        vm.config.outDirectory = URL(fileURLWithPath: "/tmp/out-B", isDirectory: true)
        await vm.undoLastRun()
        await vm.redoLastRun()
        // Redo should use snapshot A, not current B.
        let entries = await store.entries(for: firstID)
        let redoEntry = entries.last
        #expect(redoEntry?.configSnapshot.outDirectory.path == "/tmp/out-A")
    }
}
