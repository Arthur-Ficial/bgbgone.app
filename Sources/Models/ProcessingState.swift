import Foundation

/// One file's position in the queue. Matches the design's status pill states 1:1.
///
/// Lifecycle: `.raw → .queued → .processing → .done(ms)`, or `.processing → .error(msg)`.
/// `.done` is terminal until the user explicitly reprocesses (back to `.queued`).
/// `.error` is requeueable.
enum ProcessingState: Sendable, Hashable, Codable {
    case raw
    case queued
    case processing
    case done(milliseconds: Int)
    case error(message: String)

    /// `true` if the user can move this back to `.queued` by hitting Reprocess.
    var isRequeueable: Bool {
        switch self {
        case .raw, .error: true
        case .queued, .processing, .done: false
        }
    }

    /// Status pill colour-class. Strings match `design/project/styles.css` `.fr-state.*` rules.
    var pillClass: String {
        switch self {
        case .raw: "raw"
        case .queued: "queued"
        case .processing: "processing"
        case .done: "done"
        case .error: "error"
        }
    }
}
