import Foundation
import Testing
@testable import bgbgone_app

@Suite("BgBgOneCommand argv contract")
struct BgBgOneCommandTests {
    static let input = URL(fileURLWithPath: "/Users/me/in.jpg")
    static let output = URL(fileURLWithPath: "/Users/me/cutouts/in_bgbgone.png")

    @Test func transparentPng() throws {
        let cmd = BgBgOneCommand(
            input: Self.input, output: Self.output,
            background: .transparent, format: .png
        )
        #expect(try cmd.arguments() == [
            "/Users/me/in.jpg",
            "-o", "/Users/me/cutouts/in_bgbgone.png",
            "--to", "png",
            "--json", "--quiet",
        ])
    }

    @Test func solidColorWhite() throws {
        let cmd = BgBgOneCommand(
            input: Self.input,
            output: URL(fileURLWithPath: "/Users/me/cutouts/in_bgbgone.jpg"),
            background: .color(hex: "#ffffff"),
            format: .jpg
        )
        #expect(try cmd.arguments() == [
            "/Users/me/in.jpg",
            "-o", "/Users/me/cutouts/in_bgbgone.jpg",
            "--bg", "color:#ffffff",
            "--to", "jpg",
            "--json", "--quiet",
        ])
    }

    @Test func solidColorBlueShort() throws {
        let cmd = BgBgOneCommand(
            input: Self.input, output: Self.output,
            background: .color(hex: "#06c"),
            format: .png
        )
        #expect(try cmd.arguments() == [
            "/Users/me/in.jpg",
            "-o", "/Users/me/cutouts/in_bgbgone.png",
            "--bg", "color:#06c",
            "--to", "png",
            "--json", "--quiet",
        ])
    }

    @Test func backgroundImageWithCoverFit() throws {
        let bg = URL(fileURLWithPath: "/Users/me/bgs/beach.jpg")
        let cmd = BgBgOneCommand(
            input: Self.input, output: Self.output,
            background: .image(bg),
            format: .png
        )
        #expect(try cmd.arguments() == [
            "/Users/me/in.jpg",
            "-o", "/Users/me/cutouts/in_bgbgone.png",
            "--bg", "image:/Users/me/bgs/beach.jpg",
            "--bg-fit", "cover",
            "--to", "png",
            "--json", "--quiet",
        ])
    }

    @Test func allFourFormats() throws {
        for format in OutputFormat.allCases {
            let out = URL(fileURLWithPath: "/out/x_bgbgone.\(format.fileExtension)")
            let args = try BgBgOneCommand(
                input: Self.input, output: out,
                background: .transparent, format: format
            ).arguments()
            #expect(args.contains("--to"))
            #expect(args.contains(format.cliValue))
        }
    }

    @Test func relativeInputRejected() {
        let cmd = BgBgOneCommand(
            input: URL(fileURLWithPath: "in.jpg", relativeTo: URL(fileURLWithPath: "/tmp")),
            output: Self.output,
            background: .transparent, format: .png
        )
        // Even relative-to absolute resolves to an absolute path, so test with a truly
        // relative URL — use the `string:` initialiser.
        let trulyRelative = BgBgOneCommand(
            input: URL(string: "in.jpg")!,
            output: Self.output,
            background: .transparent, format: .png
        )
        _ = cmd // suppress unused warning; the path-relativeTo case resolves to absolute.
        #expect(throws: BgBgOneCommand.CommandError.relativeInput) {
            try trulyRelative.arguments()
        }
    }

    @Test func badHexRejected() {
        let cmd = BgBgOneCommand(
            input: Self.input, output: Self.output,
            background: .color(hex: "white"),
            format: .png
        )
        #expect(throws: BgBgOneCommand.CommandError.unsupportedColorHex) {
            try cmd.arguments()
        }
    }

    @Test func nameTokenExpansion() {
        let input = URL(fileURLWithPath: "/Users/me/photos/anna-portrait.heic")
        let out = BgBgOneCommand.resolveOutputURL(
            for: input,
            in: URL(fileURLWithPath: "/Users/me/cutouts"),
            pattern: "{name}_bgbgone",
            format: .png
        )
        #expect(out == URL(fileURLWithPath: "/Users/me/cutouts/anna-portrait_bgbgone.png"))
    }

    @Test func paddedInstanceToken() {
        let input = URL(fileURLWithPath: "/Users/me/photos/team.heic")
        let out = BgBgOneCommand.resolveOutputURL(
            for: input,
            in: URL(fileURLWithPath: "/Users/me/cutouts"),
            pattern: "subject_{n:02}",
            format: .png,
            instance: 7
        )
        #expect(out == URL(fileURLWithPath: "/Users/me/cutouts/subject_07.png"))
    }

    @Test func extensionTokenExpansion() {
        let input = URL(fileURLWithPath: "/Users/me/x.heic")
        let out = BgBgOneCommand.resolveOutputURL(
            for: input,
            in: URL(fileURLWithPath: "/Users/me/cutouts"),
            pattern: "{name}.{ext}",
            format: .jpg
        )
        #expect(out == URL(fileURLWithPath: "/Users/me/cutouts/x.jpg"))
    }
}
