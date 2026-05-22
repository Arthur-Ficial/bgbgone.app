import SwiftUI

/// Before/after preview pair. Empty state spans both columns and shows the drop CTA.
struct DualPreview: View {
    let selected: ImageFile?
    let isEmpty: Bool
    let background: BackgroundChoice
    let onPickFolder: () -> Void
    let onPickFiles: () -> Void

    var body: some View {
        Group {
            if let file = selected {
                HStack(spacing: 20) {
                    PreviewPane(tag: "ORIGINAL", file: file, mode: .raw, color: nil)
                    PreviewPane(
                        tag: "REMOVED",
                        file: file,
                        mode: previewMode,
                        color: previewColor
                    )
                }
            } else {
                EmptyDropPane(isEmpty: isEmpty, onPickFolder: onPickFolder, onPickFiles: onPickFiles)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .frame(height: 332)
    }

    private var previewMode: PreviewPane.Mode {
        switch background {
        case .transparent: .cutout
        case .color: .composite
        case .image: .composite
        }
    }

    private var previewColor: Color? {
        if case .color(let hex) = background { return Color(hex: hex) }
        return nil
    }
}

private struct PreviewPane: View {
    enum Mode { case raw, cutout, composite }

    let tag: String
    let file: ImageFile
    let mode: Mode
    let color: Color?

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            // Subject placeholder — a simple silhouette since we can't decode the
            // image in-process (NoBusinessLogicTests forbids CoreImage). Loaded
            // images live on disk and are processed by the spawned bgbgone Process.
            SubjectGlyph(state: file.state)
                .padding(36)

            Text(tag)
                .font(DesignFont.cap10)
                .tracking(0.14 * 10)
                .foregroundStyle(DesignColor.fgFaint)
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.regular))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var background: some View {
        switch mode {
        case .raw:
            DesignColor.bgSoft
        case .cutout:
            CheckerboardBackground()
        case .composite:
            (color ?? .white)
        }
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 12
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)
                    let isLight = (r + c).isMultiple(of: 2)
                    ctx.fill(Path(rect), with: .color(isLight ? .white : Color(white: 0.91)))
                }
            }
        }
    }
}

private struct SubjectGlyph: View {
    let state: ProcessingState
    var body: some View {
        ZStack {
            // Simple silhouette to suggest "subject" without decoding any pixels.
            // Tinted by status so the preview shows what's going on without text.
            Circle()
                .fill(tint.opacity(0.85))
                .frame(width: 80, height: 80)
                .offset(y: -40)
            Capsule()
                .fill(tint.opacity(0.6))
                .frame(width: 130, height: 170)
                .offset(y: 30)
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

private struct EmptyDropPane: View {
    let isEmpty: Bool
    let onPickFolder: () -> Void
    let onPickFiles: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignColor.fgGhost)
            Text(isEmpty ? "Drop a folder or images to begin." : "Select an image to preview.")
                .font(DesignFont.display)
                .foregroundStyle(DesignColor.fg)
            Text("PNG · JPG · HEIC · TIFF · AVIF · sub-folders OK")
                .font(DesignFont.monoSmall)
                .foregroundStyle(DesignColor.fgFaint)
            if isEmpty {
                HStack(spacing: 8) {
                    Button("Choose folder…", action: onPickFolder)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Choose files…", action: onPickFiles)
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColor.bgSoft, in: RoundedRectangle(cornerRadius: DesignRadius.regular))
    }
}
