import Foundation
import Testing
@testable import bgbgone_app

@Suite("FolderScanner against scan-tree fixture")
struct FolderScannerTests {
    static var scanTree: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        return url.appendingPathComponent("fixtures").appendingPathComponent("scan-tree")
    }

    /// Drain the stream into an in-memory transcript so tests can assert content + order.
    private static func transcript(of url: URL) async -> [ScanEvent] {
        var events: [ScanEvent] = []
        for await event in FolderScanner().scan(url) {
            events.append(event)
        }
        return events
    }

    @Test func findsAllExpectedImagesAndSkipsTheRest() async {
        let events = await Self.transcript(of: Self.scanTree)

        guard case .completed(let images, let scanned, let skipped) = events.last else {
            Issue.record("expected .completed last, got \(String(describing: events.last))")
            return
        }
        let names = Set(images.map(\.lastPathComponent))
        #expect(names == ["top.jpg", "anna.heic", "lukas.jpg", "mug.jpg", "shoe.heic"])
        // 5 images + 1 notes.txt = 6 visited files. Hidden files / .DS_Store are skipped
        // by NSDirectoryEnumerator and don't count.
        #expect(scanned == 6)
        #expect(skipped == 1)
    }

    @Test func relativePathPrefix() {
        let root = URL(fileURLWithPath: "/Users/me/photos/summer-shoot")
        let file = URL(fileURLWithPath: "/Users/me/photos/summer-shoot/raw/anna.heic")
        #expect(FolderScanner.relativePath(of: file, from: root) == "raw/")
    }

    @Test func relativePathTopLevel() {
        let root = URL(fileURLWithPath: "/Users/me/photos/summer-shoot")
        let file = URL(fileURLWithPath: "/Users/me/photos/summer-shoot/anna.heic")
        #expect(FolderScanner.relativePath(of: file, from: root) == "")
    }

    @Test func streamCancellation() async {
        let task = Task {
            var first: ScanEvent?
            for await event in FolderScanner().scan(Self.scanTree) {
                first = event
                break // cancel by breaking out
            }
            return first
        }
        let result = await task.value
        // We at least observed one event before bailing.
        #expect(result != nil)
    }
}
