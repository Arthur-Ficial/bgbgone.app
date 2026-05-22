import Foundation

/// Read-only image metadata. **No pixel decoding.** Implementations may use ImageIO
/// (`CGImageSourceCopyPropertiesAtIndex`) but never `Vision`, `CoreImage`, `CoreML`.
struct ImageMeta: Sendable, Hashable {
    let width: Int
    let height: Int
    let bytes: Int
}

enum MetaError: Error, Equatable, Sendable {
    case notFound
    case unreadable
    case unsupported
}

protocol ImageMetaReading: Sendable {
    func read(_ url: URL) throws -> ImageMeta
}
