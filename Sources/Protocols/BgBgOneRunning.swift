import Foundation

/// Service protocol: spawn `bgbgone` with a given argv and surface a parsed result.
///
/// `BgBgOneRunner` is the prod impl. Tests inject `MockBgBgOneRunning` to assert
/// `QueueRunner` ordering, concurrency caps, and error propagation without spawning
/// real processes.
protocol BgBgOneRunning: Sendable {
    /// Run the CLI with the given arguments. Throws `RunnerError` on any non-zero exit
    /// or framework failure; otherwise returns the parsed JSON result.
    func run(arguments: [String]) async throws -> RunResult
}

/// Errors surfaced by a `BgBgOneRunning` implementation. Exit-code mapping matches the
/// parent CLI's contract (`docs/design.md` in bgbgone): 1 = user error, 2 = no subject,
/// 3 = framework error.
enum RunnerError: Error, Equatable, Sendable {
    case noSubject
    case userError(stderrTail: String)
    case framework(stderrTail: String)
    case timeout
    case cancelled
    case malformedJSON
    case binaryNotExecutable(URL)
}
