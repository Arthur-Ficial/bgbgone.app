import Foundation

/// Live snapshot of the ingestion progress card. Updated by `FolderScanner` events.
struct IngestState: Sendable, Hashable {
    var folderName: String
    var scannedCount: Int
    var foundCount: Int
    /// Last few discovered paths, for the scrolling tail at the bottom of the ingest card.
    /// Capped at 4 entries by `AppViewModel` so the UI doesn't unbound-grow.
    var recentPaths: [String]
}

/// Summary chip shown briefly after an ingest completes. Auto-dismisses after 6s.
struct DropSummary: Sendable, Hashable {
    var added: Int
    var skipped: Int
    var deduped: Int
    var folderName: String
}

/// The window-level drop machine state. Matches `design/chats/chat2.md`:
///
///     idle ── drag enter ──▶ drag(hint)
///     drag(hint) ── drag leave (window) ──▶ idle
///     drag(hint) ── drop ──▶ ingest(initial)
///     ingest ── scan progress ──▶ ingest(updated)
///     ingest ── scan complete ──▶ summary(s)
///     summary ── 6s timeout / dismiss ──▶ idle
enum DropPhase: Sendable, Hashable {
    case idle
    case drag(DragHint)
    case ingest(IngestState)
    case summary(DropSummary)
}
