import Foundation
import Observation

/// In-memory ring buffer of recent debug events. The `--debug` overlay's "Log tail"
/// reads from here; `BgBgOneRunner` appends spawn / exit / stderr lines. Capped at
/// 100 entries so the panel never unbound-grows.
@MainActor
@Observable
final class DebugLog {
    static let shared = DebugLog()

    struct Event: Identifiable, Hashable, Sendable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let message: String
    }

    private(set) var events: [Event] = []
    private let cap = 100

    func append(category: String, message: String) {
        let event = Event(timestamp: .now, category: category, message: message)
        events.append(event)
        if events.count > cap { events.removeFirst(events.count - cap) }
    }

    func clear() { events.removeAll() }

    /// Snapshot helper for the CLI echo "Copy" button.
    var tailAsText: String {
        events.map { ev in
            let stamp = Self.timeFormatter.string(from: ev.timestamp)
            return "\(stamp) [\(ev.category)] \(ev.message)"
        }.joined(separator: "\n")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
