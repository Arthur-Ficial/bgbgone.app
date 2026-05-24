import Foundation
import Testing
@testable import bgbgone_app

@Suite("SourceFolder lookup (T1)")
struct SourceFolderTests {
    @Test func returnsBatchNameForBatchedFile() {
        let batch = Batch(name: "summer-shoot")
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: batch.id)
        #expect(SourceFolder.name(for: file, in: [batch]) == "summer-shoot")
    }

    @Test func returnsNilForLooseFile() {
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: nil)
        #expect(SourceFolder.name(for: file, in: []) == nil)
    }

    @Test func returnsNilWhenBatchUnknown() {
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: UUID())
        #expect(SourceFolder.name(for: file, in: []) == nil)
    }

    @Test func returnsBatchRootURLForBatchedFile() {
        let folder = URL(fileURLWithPath: "/Users/me/summer-shoot", isDirectory: true)
        let batch = Batch(name: "summer-shoot", rootURL: folder)
        let file = ImageFile(url: URL(fileURLWithPath: "/Users/me/summer-shoot/a.jpg"), batchId: batch.id)
        #expect(SourceFolder.url(for: file, in: [batch]) == folder)
    }

    @Test func returnsNilURLForLooseFile() {
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: nil)
        #expect(SourceFolder.url(for: file, in: []) == nil)
    }
}
