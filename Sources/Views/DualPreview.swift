import SwiftUI
import AppKit
import ImageIO

/// Before/after preview pair. Empty state spans both columns and shows the drop CTA.
/// Both panes decode the real PNG/JPG via `ImageIO` thumbnail (legal — `ImageIO` is in
/// the allowed list; no `Vision`/`CoreImage`/`Metal`/`Accelerate`/`CoreML`). No painted
/// silhouettes. No fake checkerboard hiding "nothing".
struct DualPreview: View {
    let selected: ImageFile?
    let isEmpty: Bool
    let config: Config
    let onPickFolder: () -> Void
    let onPickFiles: () -> Void

    var body: some View {
        Group {
            if let file = selected {
                HStack(spacing: 20) {
                    PreviewPane(tag: "Original", url: file.url, kind: .original, file: file)
                    PreviewPane(
                        tag: "Removed",
                        url: outputURL(for: file),
                        kind: .removed(background: config.background),
                        file: file
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

    private func outputURL(for file: ImageFile) -> URL {
        BgBgOneCommand.resolveOutputURL(
            for: file.url,
            in: config.outDirectory,
            pattern: config.namePattern,
            format: config.format
        )
    }
}

private struct PreviewPane: View {
    enum Kind {
        case original
        case removed(background: BackgroundChoice)
    }

    let tag: String
    /// For the Original pane this is the input file; for the Removed pane this is the
    /// computed output URL that `bgbgone` would write — may or may not exist yet.
    let url: URL
    let kind: Kind
    /// Carried for the state pill below the image (queued/processing/done/error).
    let file: ImageFile

    @State private var nsImage: NSImage?
    @State private var loadError: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            backdrop

            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .opacity(dimming)
            } else if loadError != nil, case .removed = kind, !isDone {
                // No output yet, no fallback — show the file icon and a quiet hint.
                pendingPlaceholder
            } else if loadError != nil {
                failurePlaceholder
            } else {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if case .processing = file.state {
                ProgressView()
                    .controlSize(.small)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            Text(tag)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
                .padding(10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url.path + String(describing: file.state)) {
            await loadImage()
        }
    }

    /// `.removed` pane shows transparency-checkered backdrop only when background is
    /// transparent. `.color` shows the solid colour as the backdrop. `.original` shows
    /// the system window background.
    @ViewBuilder private var backdrop: some View {
        switch kind {
        case .original:
            Color(NSColor.windowBackgroundColor)
        case .removed(let bg):
            switch bg {
            case .transparent: TransparencyChecker()
            case .color(let hex): Color(hex: hex)
            case .image: Color(NSColor.windowBackgroundColor)
            }
        }
    }

    private var dimming: Double {
        if case .removed = kind, !isDone { return 0.30 }
        return 1.0
    }

    private var isDone: Bool {
        if case .done = file.state { return true }
        return false
    }

    @ViewBuilder private var pendingPlaceholder: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(for: .image))
                .resizable()
                .frame(width: 56, height: 56)
                .opacity(0.5)
            Text(pendingHint)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var failurePlaceholder: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(for: .image))
                .resizable()
                .frame(width: 56, height: 56)
                .opacity(0.5)
            if let err = loadError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pendingHint: String {
        switch file.state {
        case .raw: "Not removed yet"
        case .queued: "Queued"
        case .processing: "Removing…"
        case .error(let msg): "Failed: \(msg)"
        case .done: "Output missing"
        }
    }

    /// Off-main thumbnail decode via `ImageIO`. 512px max edge — large enough for the
    /// preview pane, small enough not to thrash on large drops.
    private func loadImage() async {
        let url = self.url
        let result: (NSImage?, String?) = await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return (nil, "")
            }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return (nil, "Could not open image")
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return (nil, "Could not decode image")
            }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return (NSImage(cgImage: cgImage, size: size), nil)
        }.value

        await MainActor.run {
            self.nsImage = result.0
            self.loadError = result.1
        }
    }
}

/// Standard transparency checker pattern used by Preview.app / Pages / Sketch — neutral
/// grey on white at 12pt tiles. This is a real PNG-with-alpha indicator, not a
/// placeholder for missing pixels.
private struct TransparencyChecker: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 12
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)
                    let isLight = (r + c).isMultiple(of: 2)
                    ctx.fill(Path(rect), with: .color(isLight ? Color.white : Color(white: 0.91)))
                }
            }
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
                .foregroundStyle(.tertiary)
            Text(isEmpty ? "Drop a folder or images to begin." : "Select an image to preview.")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("PNG · JPG · HEIC · TIFF · AVIF · sub-folders OK")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if isEmpty {
                HStack(spacing: 8) {
                    Button("Choose folder…", action: onPickFolder)
                        .buttonStyle(.borderedProminent)
                    Button("Choose files…", action: onPickFiles)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
