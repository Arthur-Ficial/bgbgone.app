import Foundation

/// Pure-logic lookup for the "Source Folder" column (T1) and "Open Source Folder"
/// action (T4). Loose-dropped files have no batch and return `nil` — the file-list
/// renders an em-dash and T4 disables the open button.
///
/// T13 ("Single Files" virtual batch) layers on top by giving loose drops a singleton
/// batch ID with `rootURL = nil` — `name(for:in:)` then returns "Single Files" and
/// `url(for:in:)` still returns `nil`, keeping the T4 disable rule.
///
/// Both call sites that fire per-row-per-redraw (`name(for:in:)` from the file
/// list cell and `url(for:in:)` from the action menu) take an index dictionary
/// in the hot path so lookups are O(1) instead of O(batches). The
/// array-shaped APIs remain for callers (and tests) that don't keep a dict
/// around.
enum SourceFolder {
    static func name(for file: ImageFile, in batches: [Batch]) -> String? {
        guard let batchId = file.batchId else { return nil }
        return batches.first { $0.id == batchId }?.name
    }

    static func name(for file: ImageFile, byID: [Batch.ID: Batch]) -> String? {
        guard let batchId = file.batchId else { return nil }
        return byID[batchId]?.name
    }

    static func url(for file: ImageFile, in batches: [Batch]) -> URL? {
        guard let batchId = file.batchId else { return nil }
        return batches.first { $0.id == batchId }?.rootURL
    }

    static func url(for file: ImageFile, byID: [Batch.ID: Batch]) -> URL? {
        guard let batchId = file.batchId else { return nil }
        return byID[batchId]?.rootURL
    }
}
