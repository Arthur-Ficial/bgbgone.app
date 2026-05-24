import Foundation

/// Parses the bgbgone `--filter` DSL string into a `FilterChain`. Used by the
/// AdvancedChainEditor (T14) for live validation and round-tripping between GUI
/// controls and free-form text.
///
/// Grammar (locked, matches bgbgone/Sources/Core/FilterParser.swift):
/// ```
/// chain  := stage (";" stage)*
/// stage  := [layer ":"] filter ("," filter)*       (we treat each filter as its own stage for SSOT)
/// filter := name ("=" arg (":" arg)*)?
/// arg    := value | key "=" value
/// ```
enum FilterChainParser {
    enum ParseError: Error, Equatable {
        case unknownLayer(String)
        case emptyFilterName
    }

    static func parse(_ text: String) throws -> FilterChain {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return FilterChain(recipes: []) }

        var recipes: [FilterRecipe] = []
        for rawStage in trimmed.split(separator: ";", omittingEmptySubsequences: true) {
            let stage = rawStage.trimmingCharacters(in: .whitespaces)
            for rawFilter in stage.split(separator: ",", omittingEmptySubsequences: true) {
                let filterText = String(rawFilter).trimmingCharacters(in: .whitespaces)
                let (layer, body) = try splitLayer(filterText)
                let recipe = try parseFilterBody(body, layer: layer)
                recipes.append(recipe)
            }
        }
        return FilterChain(recipes: recipes)
    }

    private static func splitLayer(_ text: String) throws -> (FilterRecipe.Layer?, String) {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (nil, text) }
        let head = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rest = String(parts[1]).trimmingCharacters(in: .whitespaces)
        // If `head` looks like a layer name, treat it as the layer.
        if let layer = FilterRecipe.Layer(rawValue: head) {
            return (layer, rest)
        }
        // If `head` contains an `=`, it isn't a layer prefix — it's a filter with args.
        if head.contains("=") { return (nil, text) }
        // Looks like an unknown layer prefix.
        throw ParseError.unknownLayer(head)
    }

    private static func parseFilterBody(_ text: String, layer: FilterRecipe.Layer?) throws -> FilterRecipe {
        let parts = text.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw ParseError.emptyFilterName }
        if parts.count == 1 {
            return FilterRecipe(layer: layer, name: name, args: [])
        }
        let argsString = String(parts[1])
        let args: [FilterRecipe.Arg] = argsString
            .split(separator: ":", omittingEmptySubsequences: false)
            .map(String.init)
            .map { token in
                let kv = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if kv.count == 2 {
                    return FilterRecipe.Arg.keyed(String(kv[0]), String(kv[1]))
                } else {
                    return FilterRecipe.Arg.positional(token)
                }
            }
        return FilterRecipe(layer: layer, name: name, args: args)
    }
}
