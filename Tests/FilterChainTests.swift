import Foundation
import Testing
@testable import bgbgone_app

@Suite("FilterChain DSL composition (T14)")
struct FilterChainTests {
    @Test func emptyChainEmitsEmptyString() {
        let chain = FilterChain(recipes: [])
        #expect(chain.dslString == "")
    }

    @Test func singleRecipeNoArgs() {
        let chain = FilterChain(recipes: [
            FilterRecipe(layer: .bg, name: "grayscale", args: [])
        ])
        #expect(chain.dslString == "bg:grayscale")
    }

    @Test func defaultLayerIsAll() {
        let chain = FilterChain(recipes: [
            FilterRecipe(layer: nil, name: "grayscale", args: [])
        ])
        #expect(chain.dslString == "grayscale")
    }

    @Test func positionalArgsJoinedWithColon() {
        let chain = FilterChain(recipes: [
            FilterRecipe(layer: .mask, name: "feather", args: [.positional("8")])
        ])
        #expect(chain.dslString == "mask:feather=8")
    }

    @Test func multiplePositionalArgsJoinWithColon() {
        // Genuinely colon-separated positionals, e.g. bgbgone's `bloom=intensity:radius`
        // (catalogue example `bloom=0.5:10`). NOTE: `translate` is NOT this shape — it
        // takes a single `X,Y` comma value, so Config composes it as one positional.
        let chain = FilterChain(recipes: [
            FilterRecipe(name: "bloom", args: [.positional("0.5"), .positional("10")])
        ])
        #expect(chain.dslString == "bloom=0.5:10")
    }

    @Test func keyedArgsUseKeyEqualsValue() {
        let chain = FilterChain(recipes: [
            FilterRecipe(layer: .fg, name: "outline", args: [.keyed("color", "#fff"), .keyed("width", "3")])
        ])
        #expect(chain.dslString == "fg:outline=color=#fff:width=3")
    }

    @Test func twoStagesJoinedWithSemicolon() {
        let chain = FilterChain(recipes: [
            FilterRecipe(layer: .mask, name: "feather", args: [.positional("8")]),
            FilterRecipe(layer: .bg, name: "grayscale", args: []),
        ])
        #expect(chain.dslString == "mask:feather=8;bg:grayscale")
    }
}

@Suite("FilterChainParser (T14)")
struct FilterChainParserTests {
    @Test func parsesEmptyStringToEmptyChain() throws {
        let chain = try FilterChainParser.parse("")
        #expect(chain.recipes.isEmpty)
    }

    @Test func parsesSingleStageNoArgs() throws {
        let chain = try FilterChainParser.parse("grayscale")
        #expect(chain.recipes.count == 1)
        #expect(chain.recipes[0].layer == nil)
        #expect(chain.recipes[0].name == "grayscale")
        #expect(chain.recipes[0].args.isEmpty)
    }

    @Test func parsesLayerPrefix() throws {
        let chain = try FilterChainParser.parse("bg:grayscale")
        #expect(chain.recipes[0].layer == .bg)
        #expect(chain.recipes[0].name == "grayscale")
    }

    @Test func parsesPositionalArgs() throws {
        let chain = try FilterChainParser.parse("mask:feather=8")
        #expect(chain.recipes[0].args == [.positional("8")])
    }

    @Test func parsesKeyedArgs() throws {
        let chain = try FilterChainParser.parse("fg:outline=color=#fff:width=3")
        #expect(chain.recipes[0].args == [.keyed("color", "#fff"), .keyed("width", "3")])
    }

    @Test func roundTripsThroughParser() throws {
        let original = "mask:feather=8;fg:outline=color=#fff:width=3;bg:grayscale"
        let chain = try FilterChainParser.parse(original)
        #expect(chain.dslString == original)
    }

    @Test func unknownLayerThrows() {
        #expect(throws: FilterChainParser.ParseError.unknownLayer("xyz")) {
            try FilterChainParser.parse("xyz:grayscale")
        }
    }
}
