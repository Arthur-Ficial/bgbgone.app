import Foundation

/// JSON shape emitted by `bgbgone --json` on success. Keys match the parent CLI verbatim
/// — when the CLI adds a key, add it here too, but never read keys the CLI doesn't promise.
struct RunResult: Sendable, Hashable, Codable {
    let input: URL
    let output: URL
    let algo: String
    let format: String
    let width: Int
    let height: Int

    private enum CodingKeys: String, CodingKey {
        case input, output, algo, format, width, height
    }

    init(input: URL, output: URL, algo: String, format: String, width: Int, height: Int) {
        self.input = input
        self.output = output
        self.algo = algo
        self.format = format
        self.width = width
        self.height = height
    }

    /// bgbgone emits `input` and `output` as paths (strings), not file URLs — Codable's
    /// `URL` decoding wants `file://...`. Custom init bridges that.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let inputStr = try c.decode(String.self, forKey: .input)
        let outputStr = try c.decode(String.self, forKey: .output)
        self.input = URL(fileURLWithPath: inputStr)
        self.output = URL(fileURLWithPath: outputStr)
        self.algo = try c.decode(String.self, forKey: .algo)
        self.format = try c.decode(String.self, forKey: .format)
        self.width = try c.decode(Int.self, forKey: .width)
        self.height = try c.decode(Int.self, forKey: .height)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(input.path, forKey: .input)
        try c.encode(output.path, forKey: .output)
        try c.encode(algo, forKey: .algo)
        try c.encode(format, forKey: .format)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
    }
}
