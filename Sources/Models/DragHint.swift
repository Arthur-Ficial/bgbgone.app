import Foundation

/// What the cursor is carrying during a drag. Drives the `DropVeil` copy.
/// Mirrors `design/project/app.jsx:dragLabel()` 1:1 — the classification rules
/// here MUST match what the JS demo exercises (DEMO_HINTS test cases).
struct DragHint: Sendable, Hashable {
    var folderCount: Int
    var imageCount: Int
    var otherCount: Int
    /// The first folder name encountered, when `folderCount > 0`. Used in the veil
    /// copy ("Add folder `client-headshots`"). Empty when no folders are in the drag.
    var folderName: String

    static let empty = DragHint(folderCount: 0, imageCount: 0, otherCount: 0, folderName: "")
}

/// The copy a `DropVeil` should render for a given hint. Matches the JS `dragLabel` return shape.
struct DropVeilCopy: Sendable, Hashable {
    let primary: String
    let subtitle: String
    let isBlocked: Bool
}

extension DragHint {
    /// Pure function — same five branches as `dragLabel()` in `app.jsx`. Used by both
    /// `DropMachine` and `DropVeil`; tested against the design's DEMO_HINTS.
    func veilCopy() -> DropVeilCopy {
        switch (folderCount, imageCount, otherCount) {
        // Single folder, no loose images.
        case (1, 0, _):
            return DropVeilCopy(
                primary: "Add folder \(folderName)",
                subtitle: "We'll scan it for images, including sub-folders.",
                isBlocked: false
            )

        // Multiple folders, regardless of loose-file count.
        case (let f, _, _) where f > 1:
            return DropVeilCopy(
                primary: "Add \(f) folders",
                subtitle: "We'll scan each one for images, recursively.",
                isBlocked: false
            )

        // One folder + at least one loose image.
        case (1, let i, let o) where i > 0:
            return DropVeilCopy(
                primary: "Add folder \(folderName) + \(i) \(i == 1 ? "image" : "images")",
                subtitle: o > 0 ? "\(o) non-image \(o == 1 ? "file" : "files") will be skipped." : "",
                isBlocked: false
            )

        // Many loose images.
        case (0, let i, let o) where i > 1:
            return DropVeilCopy(
                primary: "Add \(i) images",
                subtitle: o > 0 ? "\(o) non-image \(o == 1 ? "file" : "files") will be skipped." : "",
                isBlocked: false
            )

        // Exactly one image.
        case (0, 1, _):
            return DropVeilCopy(primary: "Add 1 image", subtitle: "", isBlocked: false)

        // Only non-images.
        case (0, 0, let o) where o > 0:
            return DropVeilCopy(
                primary: "Nothing to add",
                subtitle: "\(o) \(o == 1 ? "file is" : "files are") not images — drop PNG · JPG · HEIC · TIFF · AVIF.",
                isBlocked: true
            )

        default:
            return DropVeilCopy(primary: "Drop to add", subtitle: "", isBlocked: false)
        }
    }
}
