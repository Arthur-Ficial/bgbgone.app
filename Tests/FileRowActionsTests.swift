import Foundation
import Testing
@testable import bgbgone_app

@Suite("FileRowActions (T2)")
struct FileRowActionsTests {
    static let originalURL = URL(fileURLWithPath: "/tmp/in/a.jpg")
    static let cutoutURL = URL(fileURLWithPath: "/tmp/out/a_bgbgone.png")

    static func makeFile(_ url: URL = originalURL, state: ProcessingState = .raw) -> ImageFile {
        var f = ImageFile(url: url)
        f.state = state
        return f
    }

    @Test func singleSelectionRevealOriginalLabelIsSingular() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in true }
        )
        let item = actions.first(where: { $0.kind == .revealOriginal })
        #expect(item?.label == "Reveal Original in Finder")
    }

    @Test func multiSelectionRevealOriginalLabelShowsCount() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile(), Self.makeFile(URL(fileURLWithPath: "/tmp/in/b.jpg"))],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in true }
        )
        let item = actions.first(where: { $0.kind == .revealOriginal })
        #expect(item?.label == "Reveal 2 Originals in Finder")
    }

    @Test func revealCutoutDisabledWhenCutoutMissing() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { url in url != Self.cutoutURL } // original exists, cutout does not
        )
        let item = actions.first(where: { $0.kind == .revealCutout })
        #expect(item?.isEnabled == false)
    }

    @Test func revealCutoutEnabledWhenCutoutExists() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in true }
        )
        let item = actions.first(where: { $0.kind == .revealCutout })
        #expect(item?.isEnabled == true)
    }

    @Test func openOriginalDisabledWhenOriginalMissing() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in false }
        )
        let item = actions.first(where: { $0.kind == .openOriginal })
        #expect(item?.isEnabled == false)
    }

    @Test func emitsSevenActionKinds() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in true }
        )
        let kinds = actions.map(\.kind)
        #expect(kinds.contains(.revealOriginal))
        #expect(kinds.contains(.revealCutout))
        #expect(kinds.contains(.openOriginal))
        #expect(kinds.contains(.openCutout))
        #expect(kinds.contains(.copyOriginalPath))
        #expect(kinds.contains(.copyCutoutPath))
        #expect(kinds.contains(.removeFromQueue))
        #expect(kinds.count == 7)
    }

    @Test func removeFromQueueLabelShowsCount() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile(), Self.makeFile(URL(fileURLWithPath: "/tmp/in/b.jpg")), Self.makeFile(URL(fileURLWithPath: "/tmp/in/c.jpg"))],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in true }
        )
        let item = actions.first(where: { $0.kind == .removeFromQueue })
        #expect(item?.label == "Remove 3 from Queue")
    }

    @Test func copyOriginalPathAlwaysEnabled() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { _ in false } // copy doesn't care about existence
        )
        let item = actions.first(where: { $0.kind == .copyOriginalPath })
        #expect(item?.isEnabled == true)
    }

    @Test func copyCutoutPathDisabledWhenCutoutMissing() {
        let actions = FileRowActions.actions(
            for: [Self.makeFile()],
            cutoutURL: { _ in Self.cutoutURL },
            fileExists: { url in url != Self.cutoutURL }
        )
        let item = actions.first(where: { $0.kind == .copyCutoutPath })
        #expect(item?.isEnabled == false)
    }
}
