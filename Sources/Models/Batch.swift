import Foundation

/// A folder-drop grouping in the file list. Renders as a collapsible header row above
/// its member files — see `design/project/app.jsx` `FileList` + `.batch-row` styles.
struct Batch: Sendable, Identifiable, Hashable {
    let id: UUID

    /// Folder name (e.g. `summer-shoot` or `product-archive/2025-q2`).
    let name: String

    /// When the user dropped this folder. Rendered as relative ("Today, 09:14", "Yesterday").
    let addedAt: Date

    /// How many images were added from this folder.
    var imageCount: Int

    /// How many non-image files were skipped during ingest.
    var skippedCount: Int

    /// User-collapsed flag for the file list.
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        name: String,
        addedAt: Date = .now,
        imageCount: Int = 0,
        skippedCount: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.addedAt = addedAt
        self.imageCount = imageCount
        self.skippedCount = skippedCount
        self.isCollapsed = isCollapsed
    }
}
