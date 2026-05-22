import Foundation

/// One image in the queue. Pure value type — `AppViewModel` owns the `[ImageFile]` array
/// and replaces entries on state transitions (no reference identity).
struct ImageFile: Sendable, Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String

    /// Image dimensions read from `ImageMetaReader`. Optional because metadata is read async.
    var width: Int?
    var height: Int?

    /// File size in bytes from `FileManager`. Optional for the same reason as dimensions.
    var bytes: Int?

    var state: ProcessingState
    var modifiedAt: Date

    /// Batch grouping — non-nil when the file came in via a folder drop.
    var batchId: Batch.ID?

    /// `summer-shoot/` style prefix shown before the filename when this file is in a batch.
    /// Empty string when not batched. Computed by `FolderScanner` from the drop root.
    var relativePath: String

    init(
        id: UUID = UUID(),
        url: URL,
        state: ProcessingState = .raw,
        modifiedAt: Date = .now,
        batchId: Batch.ID? = nil,
        relativePath: String = ""
    ) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.state = state
        self.modifiedAt = modifiedAt
        self.batchId = batchId
        self.relativePath = relativePath
    }
}
