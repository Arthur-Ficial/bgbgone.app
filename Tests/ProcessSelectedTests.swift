import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("AppViewModel selection-aware processing (T5)")
struct ProcessSelectedTests {
    static func makeVM() -> AppViewModel {
        AppViewModel(
            runner: AppViewModelTests.InstantRunner(),
            scanner: FolderScanner(),
            metaReader: AppViewModelTests.StubMetaReader(),
            bootState: .ready(binary: URL(fileURLWithPath: "/tmp/bgbgone-stub")),
            historyStore: nil
        )
    }

    @Test func processSelectedOnlyProcessesGivenIDs() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        let firstTwoIDs = Set(vm.files.prefix(2).map(\.id))

        await vm.processSelected(ids: firstTwoIDs)

        var doneCount = 0
        var rawCount = 0
        for file in vm.files {
            switch file.state {
            case .done: doneCount += 1
            case .raw: rawCount += 1
            default: break
            }
        }
        #expect(doneCount == 2)
        #expect(rawCount == vm.files.count - 2)
    }

    @Test func processSelectedSkipsAlreadyDoneFiles() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processAll()
        let allIDs = Set(vm.files.map(\.id))

        // All are .done now; processSelected should be a no-op for done items.
        await vm.processSelected(ids: allIDs)

        for file in vm.files {
            guard case .done = file.state else {
                Issue.record("file \(file.name) lost .done state")
                continue
            }
        }
    }

    @Test func emptySelectionIsNoOp() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        await vm.processSelected(ids: [])
        for file in vm.files {
            if case .done = file.state {
                Issue.record("nothing should have been processed")
            }
        }
    }
}
