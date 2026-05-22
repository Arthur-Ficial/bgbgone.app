import Foundation

/// Why a file was skipped during folder ingest. Used by `DropSummary.skipped`.
enum SkipReason: Sendable, Hashable {
    case notImage
    case hidden
    case appPackage
    case symlinkCycle
    case unreadable
}

/// Streaming event from a folder scan. Used to drive the `IngestOverlay` live counts
/// and the scrolling tail of discovered paths.
enum ScanEvent: Sendable, Hashable {
    /// Any item visited (image or not). Drives the "items checked" counter.
    case scanned(url: URL, isImage: Bool)
    /// A new image was found, with the path relative to the dropped root.
    case foundImage(url: URL, relativePath: String)
    /// A file was skipped with a reason.
    case skipped(url: URL, reason: SkipReason)
    /// Final event before the stream closes.
    case completed(images: [URL], scannedCount: Int, skippedCount: Int)
}

/// Service protocol: walk a URL recursively and emit `ScanEvent`s.
/// Implementations must be cancellable and respect `Task.checkCancellation()`.
protocol FolderScanning: Sendable {
    /// Start a scan rooted at `url`. Returns an `AsyncStream<ScanEvent>` that emits
    /// in encounter order and finishes after a single `.completed` event.
    func scan(_ url: URL) -> AsyncStream<ScanEvent>
}
