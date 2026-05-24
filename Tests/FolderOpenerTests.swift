import Foundation
import Testing
@testable import bgbgone_app

@Suite("FolderOpener resolveSourceFolder (T4)")
struct FolderOpenerTests {
    static let folderA = URL(fileURLWithPath: "/Users/me/summer-shoot", isDirectory: true)
    static let folderB = URL(fileURLWithPath: "/Users/me/product-shots", isDirectory: true)

    static func batch(_ name: String, url: URL?) -> Batch {
        Batch(name: name, rootURL: url)
    }

    static func file(_ url: URL, batchID: UUID?) -> ImageFile {
        ImageFile(url: url, batchId: batchID)
    }

    @Test func sidebarBatchSelectionResolvesBatchRootURL() {
        let batch = Self.batch("summer-shoot", url: Self.folderA)
        let url = FolderOpener.resolveSourceFolder(
            sidebar: .batch(batch.id),
            batches: [batch],
            visibleFiles: []
        )
        #expect(url == Self.folderA)
    }

    @Test func sidebarAllWithSingleBatchResolvesThatBatchURL() {
        let batch = Self.batch("summer-shoot", url: Self.folderA)
        let file = Self.file(URL(fileURLWithPath: "/Users/me/summer-shoot/a.jpg"), batchID: batch.id)
        let url = FolderOpener.resolveSourceFolder(
            sidebar: .all,
            batches: [batch],
            visibleFiles: [file]
        )
        #expect(url == Self.folderA)
    }

    @Test func sidebarAllWithTwoBatchesResolvesNil() {
        let a = Self.batch("a", url: Self.folderA)
        let b = Self.batch("b", url: Self.folderB)
        let fileA = Self.file(URL(fileURLWithPath: "/Users/me/summer-shoot/a.jpg"), batchID: a.id)
        let fileB = Self.file(URL(fileURLWithPath: "/Users/me/product-shots/b.jpg"), batchID: b.id)
        let url = FolderOpener.resolveSourceFolder(
            sidebar: .all,
            batches: [a, b],
            visibleFiles: [fileA, fileB]
        )
        #expect(url == nil)
    }

    @Test func sidebarBatchWithMissingRootURLResolvesNil() {
        let batch = Self.batch("virtual", url: nil) // T13 "Single Files" virtual batch
        let url = FolderOpener.resolveSourceFolder(
            sidebar: .batch(batch.id),
            batches: [batch],
            visibleFiles: []
        )
        #expect(url == nil)
    }

    @Test func emptyFilesResolvesNil() {
        let url = FolderOpener.resolveSourceFolder(
            sidebar: .all,
            batches: [],
            visibleFiles: []
        )
        #expect(url == nil)
    }
}
