import Foundation

/// One persisted run of a single `ImageFile`. `AppViewModel` appends an entry on every
/// `RunResult` (success or `RunnerError`). `RunHistoryStore` persists `[RunHistoryEntry]`
/// per file to JSON. T6 (re-run) reads the latest entry to find the previous output to
/// Trash; T8 (undo/redo) reads the `configSnapshot` to replay the exact original run.
struct RunHistoryEntry: Sendable, Hashable, Codable, Identifiable {
    enum Outcome: Sendable, Hashable, Codable {
        case success
        case failure(code: String, message: String)
    }

    let id: UUID
    let startedAt: Date
    let finishedAt: Date
    let durationMillis: Int
    let outputURL: URL?
    let outcome: Outcome
    let configSnapshot: ConfigSnapshot
}
