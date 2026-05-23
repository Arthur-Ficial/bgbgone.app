import Foundation

/// JSON shape emitted by `bgbgone --json` on success, plus a measured wall-clock
/// `durationMillis` that the runner stamps after `Process` termination. The CLI does
/// not emit `durationMillis` — when reading from JSON it defaults to 0 and
/// `BgBgOneRunner` overwrites it with the real measurement before resuming.
struct RunResult: Sendable, Hashable, Codable {
    let input: URL
    let output: URL
    let algo: String
    let format: String
    let width: Int
    let height: Int
    /// Wall-clock spawn → exit, in milliseconds. Stamped by `BgBgOneRunner` from
    /// `ContinuousClock`; 0 when the result was decoded from JSON directly (e.g. in
    /// tests that don't model time).
    let durationMillis: Int

    private enum CodingKeys: String, CodingKey {
        case input, output, algo, format, width, height
    }

    init(input: URL, output: URL, algo: String, format: String, width: Int, height: Int, durationMillis: Int = 0) {
        self.input = input
        self.output = output
        self.algo = algo
        self.format = format
        self.width = width
        self.height = height
        self.durationMillis = durationMillis
    }

    /// bgbgone emits `input` and `output` as paths (strings), not file URLs.
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
        self.durationMillis = 0
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

    /// Return a copy with `durationMillis` replaced. Used by the runner to stamp the
    /// measured elapsed time onto a freshly-decoded JSON result.
    func withDuration(millis: Int) -> RunResult {
        RunResult(input: input, output: output, algo: algo, format: format, width: width, height: height, durationMillis: millis)
    }
}
