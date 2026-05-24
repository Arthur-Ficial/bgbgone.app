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
        var out: [URL] = []
        for file in selection {
            out.append(file.url)
            guard case .done = file.state, let cutout = cutoutURL(file), fileExists(cutout) else {
                continue
            }
            out.append(cutout)
        }
        return out
    }
}
