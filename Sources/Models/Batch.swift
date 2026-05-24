import Foundation

/// A folder-drop grouping in the file list. Renders as a collapsible header row above
/// its member files — see `design/project/app.jsx` `FileList` + `.batch-row` styles.
struct Batch: Sendable, Identifiable, Hashable {
    /// T13 — stable UUID for the synthetic "Single Files" batch that owns every
    /// loose-dropped image. The sidebar always renders a row for this batch even when
    /// no loose files have been dropped yet.
    static let singleFilesID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// T13 — single source-of-truth display name for the virtual batch. Used by T1
    /// (Source Folder column), T4 (Open Source Folder is disabled because rootURL
    /// is nil), and the sidebar row label.
    static let singleFilesDisplayName: String = "Single Files"

    let id: UUID

    /// Folder name (e.g. `summer-shoot` or `product-archive/2025-q2`).
    let name: String

    /// Absolute folder URL the batch was scanned from. `nil` for synthetic/virtual
    /// batches (T13 "Single Files" sidebar row). T4 "Open Source Folder" reads this.
    let rootURL: URL?

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
        rootURL: URL? = nil,
        addedAt: Date = .now,
        imageCount: Int = 0,
        skippedCount: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.rootURL = rootURL
        self.addedAt = addedAt
        self.imageCount = imageCount
        self.skippedCount = skippedCount
        self.isCollapsed = isCollapsed
    }
}
