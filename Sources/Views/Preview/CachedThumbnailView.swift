import SwiftUI
import AppKit

/// Thin SwiftUI wrapper over `ThumbnailCache.shared.thumbnailAsync(...)`.
/// Renders the cached `NSImage` synchronously on cache hit (zero flicker),
/// kicks off a detached decode at userInitiated priority on miss. No
/// `AsyncImage` — that API does a full-resolution decode on every URL
/// change which is what made the preview pane sluggish.
///
/// `showChecker: true` paints the standard alpha-channel checker behind
/// the image — the background is bounded by the Image's own frame
/// (via `.background`), so it matches the image's aspect ratio exactly
/// rather than filling the whole pane.
struct CachedThumbnailView: View {
    let url: URL
    var maxPixels: Int = 1024
    var showChecker: Bool = false

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .background {
                        if showChecker {
                            TransparencyChecker()
                        } else {
                            Color.clear
                        }
                    }
            } else {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url.absoluteString) {
            // Cache-only lookup (cheap, no decode) keeps hits flicker-free.
            if let hit = ThumbnailCache.shared.cached(for: url, maxPixels: maxPixels) {
                self.image = hit
                return
            }
            self.image = nil
            let loaded = await ThumbnailCache.shared.thumbnailAsync(for: url, maxPixels: maxPixels)
            if !Task.isCancelled { self.image = loaded }
        }
    }
}

/// Standard alpha-channel checker — neutral grey + white at 12pt tiles,
/// drawn with `Canvas` (stock SwiftUI, GPU-accelerated). Used as the
/// background of a thumbnail image so it matches the image's aspect
/// ratio exactly (no spill into the pane margins).
struct TransparencyChecker: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 12
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)
                    let isLight = (r + c).isMultiple(of: 2)
                    ctx.fill(Path(rect), with: .color(isLight ? Color.white : Color(white: 0.88)))
                }
            }
        }
    }
}
