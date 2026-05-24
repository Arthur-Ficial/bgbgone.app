import Foundation

/// Move-to-Trash wrapper used by T6 (re-run trashes previous output) and T8 (undo
/// trashes all outputs from the batch). Always uses `FileManager.trashItem` so files
/// remain recoverable via Finder's "Put Back".
///
/// Missing files return `nil` rather than throw — re-running a file whose previous
/// output was already deleted shouldn't error.
enum TrashService {
    @discardableResult
    static func trash(_ url: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var resulting: NSURL? = nil
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
    }
}
