import Foundation

/// Frozen, fully-Codable form of a `Config` value at the moment a run was triggered.
/// Lives in `RunHistoryEntry`. T8 redo replays runs using the snapshotted config,
/// independently of whatever the live `Config` looks like at redo time.
struct ConfigSnapshot: Sendable, Hashable, Codable {
    var outDirectory: URL
    var namePattern: String
    var background: BackgroundChoice
    var format: OutputFormat

    /// The composed `--filter` chain string used for the run. Empty when no filters were
    /// active. T14 wires the live filter UI into this field; T10 lands it as an empty
    /// string so the persistence foundation is in place first.
    var filterChain: String
}
