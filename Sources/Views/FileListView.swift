import SwiftUI

/// Finder-style file `Table`: sortable columns, multi-select, real selection model, real
/// context menu. Drives `AppViewModel.selectedId` (single) for the inspector preview.
struct FileListView: View {
    @Bindable var viewModel: AppViewModel
    let onTryDemo: () -> Void
    let onDismissSummary: () -> Void

    @State private var sortOrder: [KeyPathComparator<ImageFile>] = [
        KeyPathComparator(\ImageFile.name, order: .forward),
    ]

    var body: some View {
        Table(sortedFiles, selection: tableSelection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { file in
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text(file.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .width(min: 180, ideal: 280)

            TableColumn("Status") { file in
                StatusPill(state: file.state)
            }
            .width(min: 110, max: 140)

            TableColumn("Size", value: \.bytesSortKey) { file in
                Text(sizeText(file))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 100, max: 130)

            TableColumn("Dimensions", value: \.pixelArea) { file in
                Text(dimsText(file))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 110, max: 140)

            TableColumn("Modified", value: \.modifiedAt) { file in
                Text(file.modifiedAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 150)
        }
        .contextMenu(forSelectionType: ImageFile.ID.self) { ids in
            if ids.isEmpty {
                Button("Add files…", action: { /* handled via toolbar */ }).disabled(true)
            } else {
                Button(ids.count == 1 ? "Show in Finder" : "Show all in Finder", systemImage: "folder") {
                    let urls = viewModel.files.filter { ids.contains($0.id) }.map(\.url)
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                Divider()
                Button("Remove from Queue", systemImage: "trash", role: .destructive) {
                    viewModel.files.removeAll { ids.contains($0.id) }
                }
            }
        } primaryAction: { ids in
            if let first = ids.first {
                viewModel.selectedId = first
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if case .summary(let summary) = viewModel.dropMachine.phase {
                DropSummaryChip(summary: summary, onDismiss: onDismissSummary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
        }
        .overlay {
            if viewModel.visibleFiles.isEmpty { emptyState }
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("Drop a folder or images here")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("or use Add files… in the toolbar")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Try Demo (10 public-domain images)", action: onTryDemo)
                .buttonStyle(.bordered)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var sortedFiles: [ImageFile] {
        viewModel.visibleFiles.sorted(using: sortOrder)
    }

    private var tableSelection: Binding<Set<ImageFile.ID>> {
        Binding(
            get: {
                if let id = viewModel.selectedId { return [id] }
                return []
            },
            set: { newSet in
                viewModel.selectedId = newSet.first
            }
        )
    }

    private func sizeText(_ file: ImageFile) -> String {
        guard let bytes = file.bytes else { return "—" }
        return SelectedMeta.humanBytes(bytes)
    }

    private func dimsText(_ file: ImageFile) -> String {
        guard let w = file.width, let h = file.height else { return "—" }
        return "\(w) × \(h)"
    }
}

/// Inline green chip shown when a drop just finished.
struct DropSummaryChip: View {
    let summary: DropSummary
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(addedLine)
                .font(.callout)
                .foregroundStyle(.primary)

            if summary.skipped > 0 {
                Text("· \(summary.skipped) skipped")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var addedLine: AttributedString {
        let n = summary.added
        let unit = n == 1 ? "image" : "images"
        var s = AttributedString("Added \(n) \(unit)")
        if !summary.folderName.isEmpty {
            let from = AttributedString(" from ")
            s.append(from)
            var name = AttributedString(summary.folderName)
            name.font = .callout.italic()
            s.append(name)
        }
        return s
    }
}

/// `KeyPathComparator` needs concrete `Comparable` properties. `Optional<Int>` doesn't
/// satisfy that on its own, so we expose stable sort keys.
private extension ImageFile {
    var bytesSortKey: Int { bytes ?? -1 }
    var pixelArea: Int { (width ?? 0) * (height ?? 0) }
}
