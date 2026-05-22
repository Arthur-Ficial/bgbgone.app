import SwiftUI

/// Soft-blue veil shown during a file/folder drag-over. Red when blocked.
struct DropVeil: View {
    let hint: DragHint

    var body: some View {
        let copy = hint.veilCopy()
        let tint = copy.isBlocked ? DesignColor.red : DesignColor.accent

        ZStack {
            tint.opacity(0.09)
                .background(.ultraThinMaterial.opacity(0.82))

            VStack(spacing: 10) {
                Circle()
                    .fill(tint.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: copy.isBlocked ? "xmark.circle"
                              : hint.folderCount > 0 ? "folder.badge.plus"
                              : "square.and.arrow.down")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(tint)
                    )
                Text(copy.primary)
                    .font(DesignFont.display.weight(.medium))
                    .foregroundStyle(DesignColor.fg)
                if !copy.subtitle.isEmpty {
                    Text(copy.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(DesignColor.fgMute)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minWidth: 360)
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
            )
            .shadow(color: .black.opacity(0.18), radius: 50, x: 0, y: 20)
        }
    }
}

/// Folder-scan progress card.
struct IngestOverlay: View {
    let state: IngestState
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.white.opacity(0.86)
                .background(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignColor.bgSelected)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "folder")
                                .foregroundStyle(DesignColor.accent)
                                .font(.system(size: 17))
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("Scanning")
                                .font(DesignFont.display)
                                .foregroundStyle(DesignColor.fg)
                            Text(state.folderName)
                                .italic()
                                .font(DesignFont.display)
                                .foregroundStyle(DesignColor.accent)
                        }
                        HStack(spacing: 4) {
                            Text("\(state.foundCount)").bold().monospacedDigit()
                            Text("images found")
                            Text("·").foregroundStyle(DesignColor.fgGhost)
                            Text("\(state.scannedCount)").bold().monospacedDigit()
                            Text("items checked")
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DesignColor.fgFaint)
                    }
                }

                ProgressBar(progress: progress)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(state.recentPaths.enumerated()), id: \.offset) { idx, path in
                        HStack(spacing: 8) {
                            Text("+").foregroundStyle(DesignColor.green).bold()
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(DesignColor.fgMute)
                        .opacity(1.0 - Double(idx) * 0.18)
                    }
                }
                .frame(height: 80, alignment: .top)
                .clipped()

                Button(action: onCancel) {
                    Text("Cancel scan")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignColor.fgMute)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .frame(width: 440)
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DesignColor.border))
            .shadow(color: .black.opacity(0.18), radius: 60, x: 0, y: 24)
        }
    }

    private var progress: Double {
        let denom = Double(max(state.scannedCount + 6, 32))
        return min(1.0, Double(state.scannedCount) / denom)
    }
}

private struct ProgressBar: View {
    let progress: Double
    @State private var shimmer: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignColor.bgSoft)
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignColor.accent)
                    .frame(width: max(4, geo.size.width * progress))
                    .animation(.easeOut(duration: 0.4), value: progress)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.5), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width)
                        .offset(x: shimmer * geo.size.width)
                        .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: shimmer)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .frame(height: 3)
        .onAppear { shimmer = 1 }
    }
}
