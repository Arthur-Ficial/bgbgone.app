import Foundation
import Testing
@testable import bgbgone_app

@Suite("DropMachine state transitions")
@MainActor
struct DropMachineTests {
    @Test func startsIdle() {
        let m = DropMachine()
        #expect(m.phase == .idle)
    }

    @Test func enterDragSetsHint() {
        let m = DropMachine()
        let hint = DragHint(folderCount: 1, imageCount: 0, otherCount: 0, folderName: "shoots")
        m.handleDragEnter(hint: hint)
        guard case .drag(let h) = m.phase else { Issue.record("expected .drag"); return }
        #expect(h == hint)
    }

    @Test func dragLeaveReturnsToIdle() {
        let m = DropMachine()
        m.handleDragEnter(hint: .empty)
        m.handleDragLeave()
        #expect(m.phase == .idle)
    }

    @Test func dragLeaveFromIngestDoesNothing() {
        let m = DropMachine()
        m.handleDrop(folderName: "x")
        m.handleDragLeave()
        guard case .ingest = m.phase else { Issue.record("ingest should stick"); return }
    }

    @Test func dropTransitionsToIngest() {
        let m = DropMachine()
        m.handleDragEnter(hint: DragHint(folderCount: 1, imageCount: 0, otherCount: 0, folderName: "shoots"))
        m.handleDrop(folderName: "shoots")
        guard case .ingest(let state) = m.phase else { Issue.record("expected .ingest"); return }
        #expect(state.folderName == "shoots")
        #expect(state.scannedCount == 0)
        #expect(state.foundCount == 0)
    }

    @Test func scanEventsAccumulate() {
        let m = DropMachine()
        m.handleDrop(folderName: "shoots")
        m.applyScanEvent(.scanned(url: URL(fileURLWithPath: "/x/foo.jpg"), isImage: true))
        m.applyScanEvent(.foundImage(url: URL(fileURLWithPath: "/x/foo.jpg"), relativePath: "foo.jpg"))
        guard case .ingest(let state) = m.phase else { Issue.record("expected .ingest"); return }
        #expect(state.scannedCount == 1)
        #expect(state.foundCount == 1)
        #expect(state.recentPaths == ["foo.jpg"])
    }

    @Test func recentPathsCapAt4() {
        let m = DropMachine()
        m.handleDrop(folderName: "shoots")
        for i in 0..<10 {
            m.applyScanEvent(.foundImage(
                url: URL(fileURLWithPath: "/x/\(i).jpg"),
                relativePath: "\(i).jpg"
            ))
        }
        guard case .ingest(let state) = m.phase else { Issue.record("expected .ingest"); return }
        #expect(state.recentPaths.count == 4)
        // Last 4 wins.
        #expect(state.recentPaths == ["6.jpg", "7.jpg", "8.jpg", "9.jpg"])
        #expect(state.foundCount == 10)
    }

    @Test func completedTransitionsToSummary() {
        let m = DropMachine()
        m.handleDrop(folderName: "shoots")
        m.applyScanEvent(.foundImage(url: URL(fileURLWithPath: "/x/foo.jpg"), relativePath: "foo.jpg"))
        m.applyScanEvent(.completed(images: [URL(fileURLWithPath: "/x/foo.jpg")], scannedCount: 3, skippedCount: 2))

        guard case .summary(let summary) = m.phase else { Issue.record("expected .summary"); return }
        #expect(summary.added == 1)
        #expect(summary.skipped == 2)
        #expect(summary.folderName == "shoots")
    }

    @Test func summaryAutoDismissesAfterTimeout() async throws {
        let m = DropMachine(summaryDuration: .milliseconds(40))
        m.handleDrop(folderName: "x")
        m.applyScanEvent(.completed(images: [], scannedCount: 0, skippedCount: 0))
        // Allow the dismiss task to fire.
        try await Task.sleep(for: .milliseconds(120))
        #expect(m.phase == .idle)
    }

    @Test func manualDismissCancelsTimer() async throws {
        let m = DropMachine(summaryDuration: .seconds(60))
        m.handleDrop(folderName: "x")
        m.applyScanEvent(.completed(images: [], scannedCount: 0, skippedCount: 0))
        m.dismissSummary()
        #expect(m.phase == .idle)
    }
}
