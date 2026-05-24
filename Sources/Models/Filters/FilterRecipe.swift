import Foundation

/// One filter step in a `--filter` chain. Maps directly to the bgbgone CLI's filter
/// DSL (`bgbgone/Sources/Core/FilterParser.swift`).
///
/// Example DSL fragments:
/// * `grayscale` → layer nil, name "grayscale", args []
/// * `bg:blur=20` → layer .bg, name "blur", args [.positional("20")]
/// * `fg:outline=color=#fff:width=3` → layer .fg, name "outline", args [.keyed(...), .keyed(...)]
struct FilterRecipe: Sendable, Hashable, Codable {
    enum Layer: String, Sendable, Hashable, Codable {
        case fg, bg, all, mask
    }

    enum Arg: Sendable, Hashable, Codable {
        case positional(String)
        case keyed(String, String)

        /// Render this arg in DSL syntax. `positional("8")` → `8`; `keyed("color", "#fff")` → `color=#fff`.
        var dslString: String {
            switch self {
            case .positional(let v): return v
            case .keyed(let k, let v): return "\(k)=\(v)"
            }
        }
    }

    /// `nil` means "apply to the composite (default = all)".
    var layer: Layer?
    var name: String
    var args: [Arg]

    var dslString: String {
        let prefix = layer.map { "\($0.rawValue):" } ?? ""
        if args.isEmpty {
            return "\(prefix)\(name)"
        }
        let argsString = args.map(\.dslString).joined(separator: ":")
        return "\(prefix)\(name)=\(argsString)"
    }
}
