import SwiftUI

/// The scrolling file list with batch grouping.
struct FileListView: View {
    @Bindable var viewModel: AppViewModel
    let onDismissSummary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.files.isEmpty {
                        emptyState
                    } else {
                        ForEach(rowDescriptors, id: \.id) { desc in
                            switch desc.kind {
                            case .batchHeader(let batch):
                                BatchHeaderRow(batch: batch) {
                                    if let idx = viewModel.batches.firstIndex(where: { $0.id == batch.id }) {
                                        viewModel.batches[idx].isCollapsed.toggle()
                                    }
                                }
                            case .file(let file):
                                FileRow(
                                    file: file,
                                    isSelected: viewModel.selectedId == file.id,
                                    onTap: { viewModel.selectedId = file.id }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(DesignColor.bg)
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("\(viewModel.files.count)").bold().foregroundStyle(DesignColor.fg)
                Text("images").foregroundStyle(DesignColor.fgMute)
            }
            .font(DesignFont.uiSmall)
            if !viewModel.batches.isEmpty {
                Text("·").foregroundStyle(DesignColor.fgGhost)
                HStack(spacing: 4) {
                    Text("\(viewModel.batches.count)").bold().foregroundStyle(DesignColor.fg)
                    Text("folders").foregroundStyle(DesignColor.fgMute)
                }
                .font(DesignFont.uiSmall)
            }
            Spacer()
            if case .summary(let summary) = viewModel.dropMachine.phase {
                DropSummaryChip(summary: summary, onDismiss: onDismissSummary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(minHeight: 38)
        .overlay(alignment: .top) {
            Rectangle().fill(DesignColor.borderSoft).frame(height: 1)
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(DesignColor.fgGhost)
            Text("Drop a folder or images here")
                .font(DesignFont.display)
                .foregroundStyle(DesignColor.fg)
            Text("or use Add files…")
                .font(DesignFont.monoSmall)
                .foregroundStyle(DesignColor.fgFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    /// One render row per visible item. Pre-computed so the SwiftUI ForEach gets a
    /// stable `id` list and doesn't redraw on every batch update.
    private var rowDescriptors: [RowDescriptor] {
        var seenBatch: Set<UUID> = []
        var rows: [RowDescriptor] = []
        for file in viewModel.files {
            if let bid = file.batchId,
               let batch = viewModel.batches.first(where: { $0.id == bid }) {
                if !seenBatch.contains(bid) {
                    rows.append(RowDescriptor(id: "h-\(bid.uuidString)", kind: .batchHeader(batch)))
                    seenBatch.insert(bid)
                }
                if batch.isCollapsed { continue }
            }
            rows.append(RowDescriptor(id: "f-\(file.id.uuidString)", kind: .file(file)))
        }
        return rows
    }

    private struct RowDescriptor {
        let id: String
        let kind: Kind
        enum Kind {
            case batchHeader(Batch)
            case file(ImageFile)
        }
    }
}

private struct BatchHeaderRow: View {
    let batch: Batch
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(batch.isCollapsed ? -90 : 0))
                        .foregroundStyle(DesignColor.fgMute)
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignColor.fgMute)
                    Text(batch.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DesignColor.fg)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 0) {
                Text("\(batch.imageCount) \(batch.imageCount == 1 ? "image" : "images")")
                if batch.skippedCount > 0 {
                    Text(" · ").foregroundStyle(DesignColor.fgGhost)
                    Text("\(batch.skippedCount) skipped").foregroundStyle(DesignColor.amber)
                }
            }
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(DesignColor.fgFaint)

            Text(relativeAddedAt(batch.addedAt))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(DesignColor.fgGhost)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(DesignColor.borderSoft).frame(height: 1)
        }
    }

    private func relativeAddedAt(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct FileRow: View {
    let file: ImageFile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Thumbnail(state: file.state)
                    .frame(width: 36, height: 36)
                HStack(spacing: 0) {
                    if !file.relativePath.isEmpty {
                        Text(file.relativePath)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(DesignColor.fgFaint)
                    }
                    Text(file.name)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignColor.fg)
                }
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(dimsLine)
                    .font(DesignFont.mono)
                    .foregroundStyle(DesignColor.fgFaint)
                    .frame(minWidth: 80, alignment: .trailing)

                StatusPill(state: file.state)
                    .frame(minWidth: 96, alignment: .trailing)

                Text(relativeModified)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DesignColor.fgFaint)
                    .frame(minWidth: 96, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? DesignColor.bgSelected : .clear)
        )
        .padding(.leading, file.batchId != nil ? 18 : 0)
        .overlay(alignment: .leading) {
            if file.batchId != nil {
                Rectangle()
                    .fill(DesignColor.borderSoft)
                    .frame(width: 1)
                    .padding(.leading, 18)
            }
        }
    }

    private var dimsLine: String {
        guard let w = file.width, let h = file.height else { return "" }
        return "\(w) × \(h)"
    }

    private var relativeModified: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: file.modifiedAt, relativeTo: .now)
    }
}

private struct Thumbnail: View {
    let state: ProcessingState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(DesignColor.bgSoft)
            Image(systemName: "photo")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(tint)
        }
    }

    private var tint: Color {
        switch state {
        case .raw: DesignColor.fgGhost
        case .queued: DesignColor.accent
        case .processing: DesignColor.amber
        case .done: DesignColor.green
        case .error: DesignColor.red
        }
    }
}

struct DropSummaryChip: View {
    let summary: DropSummary
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(DesignColor.green)
                .frame(width: 6, height: 6)
                .padding(.trailing, 8)
            HStack(spacing: 4) {
                Text("Added")
                Text("\(summary.added)").bold().monospacedDigit()
                Text(summary.added == 1 ? "image" : "images")
                if !summary.folderName.isEmpty {
                    Text("from")
                    Text(summary.folderName).italic()
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(DesignColor.fg)

            if summary.skipped > 0 {
                Text("  ·  \(summary.skipped) skipped")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignColor.fgMute)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignColor.fgFaint)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignColor.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(DesignColor.green.opacity(0.22))
        )
    }
}
