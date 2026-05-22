import Foundation
import Testing
@testable import bgbgone_app

/// `DragHint.veilCopy()` is a 1:1 port of `dragLabel()` in `design/project/app.jsx`.
/// These cases match the design's DEMO_HINTS so any drift surfaces immediately.
@Suite("DragHint veil copy")
struct DragHintTests {
    @Test func dragOneFolder() {
        let copy = DragHint(folderCount: 1, imageCount: 0, otherCount: 0, folderName: "client-headshots").veilCopy()
        #expect(copy.primary == "Add folder client-headshots")
        #expect(copy.subtitle == "We'll scan it for images, including sub-folders.")
        #expect(!copy.isBlocked)
    }

    @Test func dragMultipleFolders() {
        let copy = DragHint(folderCount: 3, imageCount: 0, otherCount: 0, folderName: "").veilCopy()
        #expect(copy.primary == "Add 3 folders")
        #expect(copy.subtitle == "We'll scan each one for images, recursively.")
        #expect(!copy.isBlocked)
    }

    @Test func dragManyImages() {
        let copy = DragHint(folderCount: 0, imageCount: 12, otherCount: 0, folderName: "").veilCopy()
        #expect(copy.primary == "Add 12 images")
        #expect(copy.subtitle == "")
        #expect(!copy.isBlocked)
    }

    @Test func dragOneImage() {
        let copy = DragHint(folderCount: 0, imageCount: 1, otherCount: 0, folderName: "").veilCopy()
        #expect(copy.primary == "Add 1 image")
        #expect(copy.subtitle == "")
        #expect(!copy.isBlocked)
    }

    @Test func dragMixedFolderPlusImages() {
        let copy = DragHint(folderCount: 1, imageCount: 4, otherCount: 2, folderName: "campaign-assets").veilCopy()
        #expect(copy.primary == "Add folder campaign-assets + 4 images")
        #expect(copy.subtitle == "2 non-image files will be skipped.")
        #expect(!copy.isBlocked)
    }

    @Test func dragNothingUsable() {
        let copy = DragHint(folderCount: 0, imageCount: 0, otherCount: 3, folderName: "").veilCopy()
        #expect(copy.primary == "Nothing to add")
        #expect(copy.subtitle == "3 files are not images — drop PNG · JPG · HEIC · TIFF · AVIF.")
        #expect(copy.isBlocked)
    }

    @Test func dragSingleNonImage() {
        let copy = DragHint(folderCount: 0, imageCount: 0, otherCount: 1, folderName: "").veilCopy()
        #expect(copy.primary == "Nothing to add")
        #expect(copy.subtitle == "1 file is not images — drop PNG · JPG · HEIC · TIFF · AVIF.")
        // Yes, "1 file is" is the JS demo's wording — keep parity even though it's a
        // tiny grammar oddity. If we change it, change the design first.
        #expect(copy.isBlocked)
    }

    @Test func emptyHintFallback() {
        let copy = DragHint.empty.veilCopy()
        #expect(copy.primary == "Drop to add")
    }
}
