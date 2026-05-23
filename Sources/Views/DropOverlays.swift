import SwiftUI

/// Soft veil shown during a file/folder drag-over. Tints with the system accent (or red
/// for blocked drops). System materials, system fonts.
struct DropVeil: View {
    let hint: DragHint

    var body: some View {
        let copy = hint.veilCopy()
        let tint: Color = copy.isBlocked ? .red : .accentColor

        ZStack {
            tint.opacity(0.08)
                .background(.ultraThinMaterial.opacity(0.85))

            VStack(spacing: 10) {
                Image(systemName: copy.isBlocked
                      ? "xmark.circle"
                      : hint.folderCount > 0 ? "folder.badge.plus" : "square.and.arrow.down")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(tint)
                Text(copy.primary)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                if !copy.subtitle.isEmpty {
                    Text(copy.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minWidth: 360)
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
            )
        }
    }
}

/// Folder-scan progress card. Real `ProgressView`, system materials.
struct IngestOverlay: View {
    let state: IngestState
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).opacity(0.85)
                .background(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 22))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Scanning")
                                .font(.headline)
                            Text(state.folderName)
                                .italic()
                                .font(.headline)
                                .foregroundStyle(.tint)
                        }
                        HStack(spacing: 4) {
                            Text("\(state.foundCount)").bold().monospacedDigit()
                            Text("images found")
                            Text("·").foregroundStyle(.tertiary)
                            Text("\(state.scannedCount)").bold().monospacedDigit()
                            Text("items checked")
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: progress)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.recentPaths.enumerated()), id: \.offset) { idx, path in
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .opacity(1.0 - Double(idx) * 0.18)
                    }
                }
                .frame(height: 80, alignment: .top)
                .clipped()

                Button("Cancel scan", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            .frame(width: 440)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        }
    }

    private var progress: Double {
        let denom = Double(max(state.scannedCount + 6, 32))
        return min(1.0, Double(state.scannedCount) / denom)
    }
}
