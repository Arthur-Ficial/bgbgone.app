import Foundation

/// The single source of truth for translating UI state into a `bgbgone` invocation.
///
/// Pure, `Sendable`. Tests assert every cell of the GUI-control → argv contract from
/// the plan / epic. Do **not** add ad-hoc flag composition anywhere else — every CLI
/// argument the GUI emits must pass through this type.
struct BgBgOneCommand: Sendable, Hashable {
    /// Input image absolute URL.
    let input: URL
    /// Resolved absolute output URL (computed from `Config + ImageFile`).
    let output: URL
    let background: BackgroundChoice
    let format: OutputFormat
    let algorithm: Algorithm
    /// T14 — composed `--filter` chain string. Empty / nil = no `--filter` arg
    /// emitted (CLI default behavior applies). The Settings panel's GUI controls
    /// compose this via `FilterChain.dslString`; the free-form editor binds to
    /// the resulting string directly.
    var filterChain: String?

    init(
        input: URL,
        output: URL,
        background: BackgroundChoice,
        format: OutputFormat,
        algorithm: Algorithm = .auto,
        filterChain: String? = nil
    ) {
        self.input = input
        self.output = output
        self.background = background
        self.format = format
        self.algorithm = algorithm
        self.filterChain = filterChain
    }

    enum CommandError: Error, Equatable {
        case relativeInput
        case relativeOutput
        case unsupportedColorHex
    }

    /// Validate inputs and emit the argv as `[String]`. Caller passes this directly
    /// to `Process.arguments`.
    func arguments() throws -> [String] {
        guard input.path.hasPrefix("/") else { throw CommandError.relativeInput }
        guard output.path.hasPrefix("/") else { throw CommandError.relativeOutput }

        var args: [String] = [input.path, "-o", output.path]

        switch background {
        case .transparent:
            break
        case .color(let hex):
            try Self.validateHex(hex)
            args += ["--bg", "color:\(hex)"]
        case .image(let imageURL):
            guard imageURL.path.hasPrefix("/") else { throw CommandError.relativeOutput }
            args += ["--bg", "image:\(imageURL.path)", "--bg-fit", "cover"]
        }

        args += ["--format", format.cliValue]
        if algorithm != .auto {
            args += ["--type", algorithm.cliValue]
        }
        if let filterChain, !filterChain.isEmpty {
            args += ["--filter", filterChain]
        }
        args += ["--json", "--quiet"]
        return args
    }

    /// Resolve the output file URL from a name pattern + format + 1-based instance index.
    /// Token expansion:
    ///   `{name}` / `{base}` → input stem (without extension)
    ///   `{ext}` → output extension (matches `format.fileExtension`)
    ///   `{n}` → instance index, default no-padding
    ///   `{n:NN}` → zero-padded to NN columns
    static func resolveOutputURL(
        for input: URL,
        in directory: URL,
        pattern: String,
        format: OutputFormat,
        instance: Int = 1
    ) -> URL {
        let stem = (input.lastPathComponent as NSString).deletingPathExtension
        var name = pattern
            .replacingOccurrences(of: "{name}", with: stem)
            .replacingOccurrences(of: "{base}", with: stem)
            .replacingOccurrences(of: "{ext}", with: format.fileExtension)

        // Expand {n}, {n:NN} via regex. The design only uses up to {n:02}, but be general.
        if let regex = try? Regex(#"\{n(?::(\d+))?\}"#) {
            while let match = name.firstMatch(of: regex) {
                let padding = match.output[1].substring.flatMap { Int($0) } ?? 1
                let padded = String(format: "%0\(padding)d", instance)
                name.replaceSubrange(match.range, with: padded)
            }
        }

        let bare = directory.appendingPathComponent(name, isDirectory: false)
        if bare.pathExtension == format.fileExtension { return bare }
        return bare.appendingPathExtension(format.fileExtension)
    }

    /// Reject `#abc`, `#abcdef` failures + named colours. We only let through `#rrggbb`
    /// or `#rgb` short-form. bgbgone accepts more (rgb:r,g,b, named), but the GUI's
    /// colour picker emits hex only, so we keep the door narrow.
    static func validateHex(_ hex: String) throws {
        guard hex.hasPrefix("#") else { throw CommandError.unsupportedColorHex }
        let body = String(hex.dropFirst())
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard body.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw CommandError.unsupportedColorHex
        }
        guard body.count == 3 || body.count == 6 else { throw CommandError.unsupportedColorHex }
    }
}
