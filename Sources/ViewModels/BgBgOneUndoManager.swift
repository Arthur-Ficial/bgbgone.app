import Foundation
import Observation

/// Per-batch undo/redo bookkeeping for T8. Each `register(...)` pushes an entry onto
/// the undo stack and clears the redo stack (per UndoManager semantics). `popUndo()`
/// moves the top entry to the redo stack and returns it; `popRedo()` does the reverse.
///
/// Side effects (trashing outputs, re-enqueueing files, restoring state) live in
/// `AppViewModel` — this type is pure bookkeeping so the redo/undo labels can render
/// in the menu bar (`Edit > Undo Process N images`) with live counts.
@MainActor
@Observable
final class BgBgOneUndoManager {
    struct Entry: Sendable, Hashable {
        let ids: Set<UUID>
        let snapshot: ConfigSnapshot
    }

    private(set) var undoStack: [Entry] = []
    private(set) var redoStack: [Entry] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var undoLabel: String {
        guard let top = undoStack.last else { return "Undo" }
        return "Undo Process \(top.ids.count) \(top.ids.count == 1 ? "image" : "images")"
    }

    var redoLabel: String {
        guard let top = redoStack.last else { return "Redo" }
        return "Redo Process \(top.ids.count) \(top.ids.count == 1 ? "image" : "images")"
    }

    func register(ids: Set<UUID>, snapshot: ConfigSnapshot) {
        undoStack.append(Entry(ids: ids, snapshot: snapshot))
        redoStack.removeAll()
    }

    func popUndo() -> Entry? {
        guard let last = undoStack.popLast() else { return nil }
        redoStack.append(last)
        return last
    }

    func popRedo() -> Entry? {
        guard let last = redoStack.popLast() else { return nil }
        undoStack.append(last)
        return last
    }
}
