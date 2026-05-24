import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("Single Files virtual batch (T13)")
struct SingleFilesBatchTests {
    @Test func singleFilesIDIsStableAcrossInstances() {
        let a = Batch.singleFilesID
        let b = Batch.singleFilesID
        #expect(a == b)
    }

    @Test func singleFilesDisplayNameIsStableLabel() {
        #expect(Batch.singleFilesDisplayName == "Single Files")
    }

    @Test func sourceFolderNameForLooseFileWithSingleFilesIDReturnsLabel() {
        let virtualBatch = Batch(
            id: Batch.singleFilesID,
            name: Batch.singleFilesDisplayName,
            rootURL: nil
        )
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: Batch.singleFilesID)
        #expect(SourceFolder.name(for: file, in: [virtualBatch]) == "Single Files")
    }

    @Test func sourceFolderURLForSingleFilesBatchIsNil() {
        let virtualBatch = Batch(
            id: Batch.singleFilesID,
            name: Batch.singleFilesDisplayName,
            rootURL: nil
        )
        let file = ImageFile(url: URL(fileURLWithPath: "/x.jpg"), batchId: Batch.singleFilesID)
        #expect(SourceFolder.url(for: file, in: [virtualBatch]) == nil)
    }
}
