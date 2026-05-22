import Foundation

/// Production `FolderScanning` — walks a folder tree with `NSDirectoryEnumerator` and
/// emits `ScanEvent`s as they're discovered, in encounter order. Honours the design's
/// rules: image extensions only, skip hidden files, skip `.app`/`.bundle` packages,
/// break symlink cycles.
struct FolderScanner: FolderScanning {
    /// Image extensions accepted. Matches the design's drop veil hint copy
    /// ("PNG · JPG · HEIC · TIFF · AVIF") plus a couple of obvious neighbours.
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "webp", "avif",
    ]

    func scan(_ url: URL) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached {
                await Self.walk(url, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func walk(_ root: URL, continuation: AsyncStream<ScanEvent>.Continuation) async {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey, .isPackageKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            continuation.yield(.completed(images: [], scannedCount: 0, skippedCount: 0))
            continuation.finish()
            return
        }

        var images: [URL] = []
        var scanned = 0
        var skipped = 0
        var visited: Set<URL> = []

        // `NSDirectoryEnumerator` isn't usable as a Swift `for-in` from an async context,
        // so drive it manually with `nextObject()`.
        while let next = enumerator.nextObject() {
            if Task.isCancelled { break }
            guard let item = next as? URL else { continue }

            let resolved = item.resolvingSymlinksInPath()
            if visited.contains(resolved) { continue }
            visited.insert(resolved)

            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if values?.isPackage == true {
                    skipped += 1
                    continuation.yield(.skipped(url: item, reason: .appPackage))
                    enumerator.skipDescendants()
                }
                continue
            }

            scanned += 1
            let ext = item.pathExtension.lowercased()
            if Self.imageExtensions.contains(ext) {
                images.append(item)
                let relativePath = Self.relativePath(of: item, from: root)
                continuation.yield(.scanned(url: item, isImage: true))
                continuation.yield(.foundImage(url: item, relativePath: relativePath))
            } else {
                skipped += 1
                continuation.yield(.scanned(url: item, isImage: false))
                continuation.yield(.skipped(url: item, reason: .notImage))
            }
        }

        continuation.yield(.completed(images: images, scannedCount: scanned, skippedCount: skipped))
        continuation.finish()
    }

    /// Slash-joined path from the dropped root to the file. Used as `ImageFile.relativePath`
    /// (rendered in the file list as a mono prefix before the filename).
    static func relativePath(of file: URL, from root: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let fileComponents = file.standardizedFileURL.pathComponents
        guard fileComponents.count > rootComponents.count,
              Array(fileComponents.prefix(rootComponents.count)) == rootComponents else {
            return file.lastPathComponent
        }
        let trail = fileComponents.dropFirst(rootComponents.count).dropLast()
        if trail.isEmpty { return "" }
        return trail.joined(separator: "/") + "/"
    }
}
