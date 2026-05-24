import Foundation

/// Persists per-file `[RunHistoryEntry]` arrays to a single JSON file in `directory`.
/// Used by T6 (re-run reads latest entry → trash previous output) and T8 (undo/redo
/// reads the snapshotted config to replay the original run).
///
/// The on-disk shape is `{ "<uuid-string>": [RunHistoryEntry, ...] }`. Missing file ==
/// empty store (first launch is not an error). Malformed file currently logs and
/// starts fresh; a follow-up will surface that to the user.
actor RunHistoryStore {
    /// Production location: `~/Library/Application Support/bgbgone-app/`.
    static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("bgbgone-app", isDirectory: true)
    }

    private let directory: URL
    private var store: [UUID: [RunHistoryEntry]] = [:]

    init(directory: URL) {
        self.directory = directory
    }

    private var fileURL: URL {
        directory.appendingPathComponent("run-history.json", isDirectory: false)
    }

    func append(_ entry: RunHistoryEntry, for fileID: UUID) {
        store[fileID, default: []].append(entry)
    }

    func entries(for fileID: UUID) -> [RunHistoryEntry] {
        store[fileID] ?? []
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [RunHistoryEntry]].self, from: data)
        else {
            store = [:]
            return
        }
        store = decoded.reduce(into: [UUID: [RunHistoryEntry]]()) { acc, pair in
            if let id = UUID(uuidString: pair.key) { acc[id] = pair.value }
        }
    }

    func loadAndPrune(knownFileIDs: Set<UUID>) {
        load()
        store = store.filter { knownFileIDs.contains($0.key) }
    }

    func flush() throws {
        let serializable = store.reduce(into: [String: [RunHistoryEntry]]()) { acc, pair in
            acc[pair.key.uuidString] = pair.value
        }
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(serializable)
        try data.write(to: fileURL, options: .atomic)
    }
}
