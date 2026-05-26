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

    /// Tracked output presence — true when the cutout exists on disk for the
    /// currently-relevant config. Mutated by the ViewModel on state transitions
    /// (`.done` set true; `.raw`/`.queued` set false) so view bodies never call
    /// `FileManager.fileExists` per-row, per-redraw.
    var cutoutExists: Bool = false

    /// Per-image settings (Background / Format / Algorithm / Save-to / Name
    /// pattern / Filter chain). Each file owns its config so the Inspector
    /// can switch as the user selects different rows. New drops inherit
    /// `AppViewModel.defaultConfig`.
    var config: Config

    init(
        id: UUID = UUID(),
        url: URL,
        state: ProcessingState = .raw,
        modifiedAt: Date = .now,
        batchId: Batch.ID? = nil,
        relativePath: String = "",
        config: Config = Config(outDirectory: Config.defaultOutDirectory)
    ) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.state = state
        self.modifiedAt = modifiedAt
        self.batchId = batchId
        self.relativePath = relativePath
        self.config = config
    }

    /// SSOT cutout URL for this file under a given Config. Every cell, every
    /// preview pane, every context-menu action resolves through this — never
    /// inline `BgBgOneCommand.resolveOutputURL(for: ..., in: ..., pattern: ...,
    /// format: ...)` again.
    func cutoutURL(in config: Config) -> URL {
        BgBgOneCommand.resolveOutputURL(
            for: url,
            in: config.outDirectory,
            pattern: config.namePattern,
            format: config.format
        )
    }
}
