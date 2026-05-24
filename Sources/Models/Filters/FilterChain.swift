import Foundation

/// Ordered list of `FilterRecipe`s composed into the bgbgone CLI's `--filter` argument.
/// Multiple recipes are joined with `;` (semicolons separate stages); within a stage,
/// the layer prefix and filter name compose per `FilterRecipe.dslString`.
///
/// This is the SSOT for the composed chain string emitted to the CLI by
/// `BgBgOneCommand`. The Settings panel's GUI controls (T14) compose recipes into
/// this value; the AdvancedChainEditor TextField is bound to its `dslString`.
struct FilterChain: Sendable, Hashable, Codable {
    var recipes: [FilterRecipe]

    init(recipes: [FilterRecipe] = []) {
        self.recipes = recipes
    }

    var isEmpty: Bool { recipes.isEmpty }

    /// The DSL string passed to bgbgone via `--filter "<this string>"`.
    var dslString: String {
        recipes.map(\.dslString).joined(separator: ";")
    }
}
