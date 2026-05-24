import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("Multi-select keyboard verbs (T9)")
struct MultiSelectActionsTests {
    static func makeVM() -> AppViewModel {
        AppViewModel(
            runner: AppViewModelTests.InstantRunner(),
            scanner: FolderScanner(),
            metaReader: AppViewModelTests.StubMetaReader(),
            bootState: .ready(binary: URL(fileURLWithPath: "/tmp/stub")),
            historyStore: nil
        )
    }

    @Test func selectAllVisibleFillsSelectedIds() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        vm.selectAllVisible()
        #expect(vm.selectedIds.count == vm.visibleFiles.count)
        #expect(vm.selectedIds == Set(vm.visibleFiles.map(\.id)))
    }

    @Test func deselectAllClearsSelectedIds() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        vm.selectAllVisible()
        vm.deselectAll()
        #expect(vm.selectedIds.isEmpty)
    }

    @Test func removeFilesDropsFromQueue() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        let total = vm.files.count
        let firstTwo = Set(vm.files.prefix(2).map(\.id))
        vm.removeFiles(ids: firstTwo)
        #expect(vm.files.count == total - 2)
    }

    @Test func removeFilesClearsSelectedIds() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        vm.selectAllVisible()
        let firstID = vm.files[0].id
        vm.removeFiles(ids: [firstID])
        #expect(!vm.selectedIds.contains(firstID))
    }

    @Test func selectedIdMirrorsSelectedIdsFirst() async {
        let vm = Self.makeVM()
        await vm.handleDrop(urls: [AppViewModelTests.scanTree])
        let firstID = vm.files[0].id
        vm.selectedIds = [firstID]
        #expect(vm.selectedId == firstID)
        vm.selectedIds = []
        #expect(vm.selectedId == nil)
    }
}
