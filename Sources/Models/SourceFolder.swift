import Foundation

/// Pure-logic lookup for the "Source Folder" column (T1) and "Open Source Folder"
/// action (T4). Loose-dropped files have no batch and return `nil` — the file-list
/// renders an em-dash and T4 disables the open button.
///
/// T13 ("Single Files" virtual batch) layers on top by giving loose drops a singleton
/// batch ID with `rootURL = nil` — `name(for:in:)` then returns "Single Files" and
/// `url(for:in:)` still returns `nil`, keeping the T4 disable rule.
enum SourceFolder {
    static func name(for file: ImageFile, in batches: [Batch]) -> String? {
        guard let batchId = file.batchId else { return nil }
        return batches.first { $0.id == batchId }?.name
    }

    static func url(for file: ImageFile, in batches: [Batch]) -> URL? {
        guard let batchId = file.batchId else { return nil }
        return batches.first { $0.id == batchId }?.rootURL
    }
}
