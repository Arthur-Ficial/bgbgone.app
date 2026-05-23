import Foundation
import ImageIO

/// ImageIO-based metadata reader. Reads **only** dimensions + file size; never decodes
/// pixels and never imports `CoreImage` / `Vision`. This is the only image-related
/// framework allowed in `bgbgone-app` (and it's metadata-only).
///
/// Used by `AppViewModel` to populate the file list dims column. Pixel work happens
/// inside the spawned `bgbgone` process.
struct ImageMetaReader: ImageMetaReading {
    func read(_ url: URL) throws -> ImageMeta {
        guard FileManager.default.fileExists(atPath: url.path) else { throw MetaError.notFound }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw MetaError.unsupported
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            throw MetaError.unsupported
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs[.size] as? Int) ?? 0
        return ImageMeta(width: width, height: height, bytes: bytes)
    }
}
