import AppKit
import ImageIO

/// NSCache-backed ImageIO thumbnail loader (T11). Hits CGImageSource's built-in
/// thumbnail path with a max pixel size so we never decode full images into memory
/// for the file-list cells. Cache key is the URL string.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 512
    }

    /// Return a thumbnail not larger than `maxPixels` on the long edge, or nil if the
    /// image can't be decoded. Synchronous — callers should off-load to background if
    /// they wish; ImageIO's thumbnail path is fast (≤2ms for typical photos).
    func thumbnail(for url: URL, maxPixels: Int = 64) -> NSImage? {
        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) { return cached }

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
        let image = NSImage(cgImage: cgImage, size: NSSize(width: maxPixels, height: maxPixels))
        cache.setObject(image, forKey: key)
        return image
    }
}
