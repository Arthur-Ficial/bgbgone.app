import SwiftUI

/// Per-item run history pane shown inside the inspector. Loads entries asynchronously
/// from `RunHistoryStore` for the currently selected `ImageFile`, newest-first.
///
/// T10 lands this view. T6/T8/T11 read the same `RunHistoryStore` for re-run, undo,
/// and the cutout column — this view is the read-side surface of the same data.
struct RunHistoryView: View {
    let file: ImageFile?
    let store: RunHistoryStore?

    @State private var entries: [RunHistoryEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run History")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            if entries.isEmpty {
                Text("No runs yet for this file.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(entries.reversed()) { entry in
                        RunHistoryRow(entry: entry)
                        Divider()
                    }
                }
            }
        }
        .task(id: file?.id) { await reload() }
    }

    private func reload() async {
        guard let file, let store else {
            entries = []
            return
        }
        entries = await store.entries(for: file.id)
    }
}

private struct RunHistoryRow: View {
    let entry: RunHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.startedAt, style: .date)
                    .font(.callout)
                Text(entry.startedAt, style: .time)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.durationMillis) ms")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            outcomeRow
            if let url = entry.outputURL {
                Text(url.lastPathComponent)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var outcomeRow: some View {
        switch entry.outcome {
        case .success:
            Label("Success", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.footnote)
                .foregroundStyle(.green)
        case .failure(let code, let message):
            Label(code, systemImage: "xmark.octagon.fill")
                .labelStyle(.titleAndIcon)
                .font(.footnote)
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
