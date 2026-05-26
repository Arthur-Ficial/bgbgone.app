import Foundation

/// Pure-logic URL list builder for T3 Quick Look (Space) and "open in default app"
/// (Return). For each selected file, include the original; if the file has a `.done`
/// state and the cutout exists on disk, also include the cutout (original first, then
/// cutout). Multi-selection interleaves per-file rather than grouping.
///
/// The View layer feeds the resulting array into `QLPreviewPanel.shared()` via the
/// `QLPreviewPanelDataSource` adapter.
enum QuickLookURLs {
    static func urls(
        for selection: [ImageFile],
        cutoutURL: (ImageFile) -> URL?,
        fileExists: (URL) -> Bool
    ) -> [URL] {
        // Finder-style preference: if the cutout (the "new" output) exists,
        // Space-bar previews the cutout. Otherwise fall back to the
        // original input. One URL per file, never both — the file list
        // already shows both thumbnails for comparison.
        selection.map { file in
            if let cutout = cutoutURL(file), fileExists(cutout) {
                return cutout
            }
            return file.url
        }
    }
}
