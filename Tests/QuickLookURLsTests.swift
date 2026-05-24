import Foundation
import Testing
@testable import bgbgone_app

@Suite("QuickLookURLs (T3)")
struct QuickLookURLsTests {
    static let original = URL(fileURLWithPath: "/tmp/in/a.jpg")
    static let cutout = URL(fileURLWithPath: "/tmp/out/a_bgbgone.png")
    static let original2 = URL(fileURLWithPath: "/tmp/in/b.jpg")
    static let cutout2 = URL(fileURLWithPath: "/tmp/out/b_bgbgone.png")

    static func makeFile(_ url: URL, done: Bool = false) -> ImageFile {
        var f = ImageFile(url: url)
        f.state = done ? .done(milliseconds: 100) : .raw
        return f
    }

    @Test func rawFileShowsOnlyOriginal() {
        let urls = QuickLookURLs.urls(
            for: [Self.makeFile(Self.original)],
            cutoutURL: { _ in Self.cutout },
            fileExists: { _ in true }
        )
        #expect(urls == [Self.original])
    }

    @Test func doneFileShowsOriginalThenCutout() {
        let urls = QuickLookURLs.urls(
            for: [Self.makeFile(Self.original, done: true)],
            cutoutURL: { _ in Self.cutout },
            fileExists: { _ in true }
        )
        #expect(urls == [Self.original, Self.cutout])
    }

    @Test func doneFileWithMissingCutoutShowsOnlyOriginal() {
        let urls = QuickLookURLs.urls(
            for: [Self.makeFile(Self.original, done: true)],
            cutoutURL: { _ in Self.cutout },
            fileExists: { url in url != Self.cutout }
        )
        #expect(urls == [Self.original])
    }

    @Test func multiSelectionInterleaves() {
        let urls = QuickLookURLs.urls(
            for: [
                Self.makeFile(Self.original, done: true),
                Self.makeFile(Self.original2, done: false),
            ],
            cutoutURL: { f in f.url == Self.original ? Self.cutout : Self.cutout2 },
            fileExists: { _ in true }
        )
        #expect(urls == [Self.original, Self.cutout, Self.original2])
    }

    @Test func emptySelectionReturnsEmpty() {
        let urls = QuickLookURLs.urls(
            for: [],
            cutoutURL: { _ in nil },
            fileExists: { _ in true }
        )
        #expect(urls.isEmpty)
    }
}
