import Foundation
import Testing
@testable import bgbgone_app

@MainActor
@Suite("BgBgOneUndoManager (T8)")
struct BgBgOneUndoManagerTests {
    static func sampleSnapshot() -> ConfigSnapshot {
        ConfigSnapshot(
            outDirectory: URL(fileURLWithPath: "/tmp/cutouts"),
            namePattern: "{name}_bgbgone",
            background: .transparent,
            format: .png,
            filterChain: ""
        )
    }

    @Test func emptyManagerCannotUndoOrRedo() {
        let mgr = BgBgOneUndoManager()
        #expect(mgr.canUndo == false)
        #expect(mgr.canRedo == false)
    }

    @Test func registerEnablesUndo() {
        let mgr = BgBgOneUndoManager()
        mgr.register(ids: [UUID(), UUID()], snapshot: Self.sampleSnapshot())
        #expect(mgr.canUndo == true)
        #expect(mgr.undoLabel == "Undo Process 2 images")
    }

    @Test func undoLabelIsSingularForOneImage() {
        let mgr = BgBgOneUndoManager()
        mgr.register(ids: [UUID()], snapshot: Self.sampleSnapshot())
        #expect(mgr.undoLabel == "Undo Process 1 image")
    }

    @Test func undoMovesEntryToRedoStack() {
        let mgr = BgBgOneUndoManager()
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]
        mgr.register(ids: ids, snapshot: Self.sampleSnapshot())
        let entry = mgr.popUndo()
        #expect(entry?.ids == ids)
        #expect(mgr.canUndo == false)
        #expect(mgr.canRedo == true)
        #expect(mgr.redoLabel == "Redo Process 3 images")
    }

    @Test func redoMovesEntryBackToUndoStack() {
        let mgr = BgBgOneUndoManager()
        let ids: Set<UUID> = [UUID()]
        let snapshot = Self.sampleSnapshot()
        mgr.register(ids: ids, snapshot: snapshot)
        _ = mgr.popUndo()
        let redoEntry = mgr.popRedo()
        #expect(redoEntry?.ids == ids)
        #expect(redoEntry?.snapshot == snapshot)
        #expect(mgr.canUndo == true)
    }

    @Test func newRegisterClearsRedoStack() {
        let mgr = BgBgOneUndoManager()
        mgr.register(ids: [UUID()], snapshot: Self.sampleSnapshot())
        _ = mgr.popUndo()
        #expect(mgr.canRedo == true)
        mgr.register(ids: [UUID()], snapshot: Self.sampleSnapshot())
        #expect(mgr.canRedo == false)
    }
}
