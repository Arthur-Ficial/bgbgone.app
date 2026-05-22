import Foundation
import Observation

/// Window-level drop state machine. Owned by `AppViewModel`, observed by the
/// `DropVeil` / `IngestOverlay` / `DropSummary` views. Pure state — no I/O.
///
/// Transitions exactly mirror `design/chats/chat2.md`:
///
///     idle ── drag enter ──▶ drag(hint)
///     drag(hint) ── drag leave ──▶ idle
///     drag(hint) ── drop ──▶ ingest(initial)
///     ingest ── scan progress ──▶ ingest(updated)
///     ingest ── scan complete ──▶ summary(s)
///     summary ── 6s timeout / dismiss ──▶ idle
@MainActor
@Observable
final class DropMachine {
    private(set) var phase: DropPhase = .idle
    private var summaryDismissTask: Task<Void, Never>?
    private let summaryDuration: Duration

    init(summaryDuration: Duration = .seconds(6)) {
        self.summaryDuration = summaryDuration
    }

    // MARK: - Drag

    func handleDragEnter(hint: DragHint) {
        cancelSummaryDismiss()
        phase = .drag(hint)
    }

    func handleDragUpdate(hint: DragHint) {
        if case .drag = phase {
            phase = .drag(hint)
        }
    }

    func handleDragLeave() {
        if case .drag = phase {
            phase = .idle
        }
    }

    // MARK: - Drop / ingest

    func handleDrop(folderName: String) {
        cancelSummaryDismiss()
        phase = .ingest(IngestState(folderName: folderName, scannedCount: 0, foundCount: 0, recentPaths: []))
    }

    /// Feed a single `ScanEvent` from `FolderScanner`. Yields the next `.ingest`
    /// snapshot (or `.summary` on completion).
    func applyScanEvent(_ event: ScanEvent) {
        guard case .ingest(var state) = phase else { return }

        switch event {
        case .scanned(_, _):
            state.scannedCount += 1
        case .foundImage(_, let relativePath):
            state.foundCount += 1
            // Cap the recent-paths tail at 4 so the UI doesn't unbound-grow.
            state.recentPaths.append(relativePath)
            if state.recentPaths.count > 4 {
                state.recentPaths.removeFirst(state.recentPaths.count - 4)
            }
        case .skipped:
            break
        case .completed(_, let scannedCount, let skippedCount):
            phase = .summary(DropSummary(
                added: state.foundCount,
                skipped: skippedCount,
                deduped: 0,
                folderName: state.folderName
            ))
            _ = scannedCount
            scheduleSummaryDismiss()
            return
        }
        phase = .ingest(state)
    }

    // MARK: - Summary

    func dismissSummary() {
        cancelSummaryDismiss()
        if case .summary = phase {
            phase = .idle
        }
    }

    private func scheduleSummaryDismiss() {
        cancelSummaryDismiss()
        let duration = summaryDuration
        summaryDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled else { return }
            self.dismissSummary()
        }
    }

    private func cancelSummaryDismiss() {
        summaryDismissTask?.cancel()
        summaryDismissTask = nil
    }
}
