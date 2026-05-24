import Foundation
import AppKit

/// Status-bar action helpers (T4). The "Open Source Folder" button is enabled iff a
/// single resolvable source folder exists for the current sidebar selection; "Open
/// Output Folder" is always enabled and creates the directory on demand.
///
/// Side-effecting calls wrap `NSWorkspace.shared.open` + `FileManager.createDirectory`
/// — no AppKit usage anywhere else in the app.
enum FolderOpener {
    /// Returns the source folder URL the user expects "Open Source Folder" to open,
    /// or `nil` when the action should be disabled. Pure logic — no I/O.
    static func resolveSourceFolder(
        sidebar: SidebarItem?,
        batches: [Batch],
        visibleFiles: [ImageFile]
    ) -> URL? {
        switch sidebar {
        case .some(.batch(let id)):
            return batches.first(where: { $0.id == id })?.rootURL
        case .some(.all), .none:
            let batchIDs = Set(visibleFiles.compactMap(\.batchId))
            guard batchIDs.count == 1, let id = batchIDs.first else { return nil }
            return batches.first(where: { $0.id == id })?.rootURL
        }
    }

    /// Open `url` in Finder. Side-effect — used by the status-bar handler.
    static func openInFinder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Create `url` as a directory if missing, then open it. Throws on creation failure;
    /// the status-bar handler surfaces the error.
    static func openOutputFolder(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
