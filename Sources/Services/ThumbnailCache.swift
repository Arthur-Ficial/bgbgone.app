import AppKit
import ImageIO

/// NSCache-backed ImageIO thumbnail loader (T11). Hits CGImageSource's built-in
/// thumbnail path with a max pixel size so we never decode full images into memory
/// for the file-list cells. Cache key is `"<url>|<maxPixels>"` so the 64px row
/// thumbs and 1024px preview thumbs never collide.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 512
    }

    /// Cache-only lookup. Returns nil on miss — does NOT decode. Cheap; safe
    /// to call from view bodies.
    func cached(for url: URL, maxPixels: Int) -> NSImage? {
        cache.object(forKey: Self.key(url: url, maxPixels: maxPixels))
    }

    /// Drop all cached sizes for `url`. Called when the on-disk file at
    /// `url` has been rewritten (e.g. after a rerun) so the next view body
    /// fetches the new pixels instead of returning the stale cache hit.
    func invalidate(url: URL) {
        for size in [64, 256, 512, 1024] {
            cache.removeObject(forKey: Self.key(url: url, maxPixels: size))
        }
    }

    /// Return a thumbnail not larger than `maxPixels` on the long edge, or nil if the
    /// image can't be decoded. Synchronous — callers should off-load to background if
    /// they wish; ImageIO's thumbnail path is fast (≤2ms for typical photos).
    func thumbnail(for url: URL, maxPixels: Int = 64) -> NSImage? {
        let key = Self.key(url: url, maxPixels: maxPixels)
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = Self.decode(url: url, maxPixels: maxPixels) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Async variant that off-loads decode to a detached task at userInitiated
    /// priority. Returns nil if decode fails. Cache lookup is sync; only the
    /// miss path is async.
    func thumbnailAsync(for url: URL, maxPixels: Int) async -> NSImage? {
        let key = Self.key(url: url, maxPixels: maxPixels)
        if let cached = cache.object(forKey: key) { return cached }
        let image = await Task.detached(priority: .userInitiated) {
            Self.decode(url: url, maxPixels: maxPixels)
        }.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    private static func key(url: URL, maxPixels: Int) -> NSString {
        "\(url.absoluteString)|\(maxPixels)" as NSString
    }

    private static func decode(url: URL, maxPixels: Int) -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
