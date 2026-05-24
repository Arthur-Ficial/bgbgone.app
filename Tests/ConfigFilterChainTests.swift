import Foundation
import Testing
@testable import bgbgone_app

@Suite("Config → FilterChain → argv (T14)")
struct ConfigFilterChainTests {
    @Test func defaultConfigEmitsEmptyChain() {
        let cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        #expect(cfg.filterChain.isEmpty)
        #expect(cfg.effectiveFilterString == "")
    }

    @Test func featherFieldComposesMaskFeather() {
        var cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        cfg.maskFeather = 8
        #expect(cfg.filterChain.dslString == "mask:feather=8")
    }

    @Test func multipleFieldsComposeIntoChain() {
        var cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        cfg.maskFeather = 8
        cfg.fgScale = 0.8
        cfg.bgGrayscale = true
        let chain = cfg.filterChain.dslString
        #expect(chain.contains("mask:feather=8"))
        #expect(chain.contains("fg:scale=0.80"))
        #expect(chain.contains("bg:grayscale"))
        #expect(chain.contains(";"))
    }

    @Test func advancedTextOverridesComposedChain() {
        var cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        cfg.maskFeather = 8
        cfg.advancedFilterText = "fg:outline=color=#000:width=5"
        #expect(cfg.effectiveFilterString == "fg:outline=color=#000:width=5")
    }

    @Test func emptyAdvancedTextDoesNotOverride() {
        var cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        cfg.maskFeather = 8
        cfg.advancedFilterText = ""
        #expect(cfg.effectiveFilterString == "mask:feather=8")
    }

    @Test func endToEndConfigToArgs() throws {
        var cfg = Config(outDirectory: URL(fileURLWithPath: "/out"))
        cfg.maskFeather = 8
        cfg.fgOutlineColor = "#fff"
        cfg.fgOutlineWidth = 3
        let cmd = BgBgOneCommand(
            input: URL(fileURLWithPath: "/in.jpg"),
            output: URL(fileURLWithPath: "/out/x_bgbgone.png"),
            background: .transparent,
            format: .png,
            filterChain: cfg.effectiveFilterString
        )
        let args = try cmd.arguments()
        guard let idx = args.firstIndex(of: "--filter") else {
            Issue.record("expected --filter in argv")
            return
        }
        let value = args[args.index(after: idx)]
        #expect(value.contains("mask:feather=8"))
        #expect(value.contains("fg:outline=color=#fff:width=3"))
    }
}
