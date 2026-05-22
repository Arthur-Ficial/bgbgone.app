import Foundation
import os

/// Production `BgBgOneRunning` — spawns the resolved binary as a `Process`, reads the
/// single JSON line on stdout, captures the stderr tail for error messaging.
///
/// One Process per call. Concurrency is enforced by `QueueRunner`, not this type.
struct BgBgOneRunner: BgBgOneRunning {
    let binary: URL
    let timeout: Duration
    /// Optional env to *add* on top of the inherited parent environment. Used by tests
    /// to drive `bgbgone-mock.sh` deterministically without setenv races.
    let extraEnvironment: [String: String]
    private let logger: Logger

    init(binary: URL, timeout: Duration = .seconds(60), extraEnvironment: [String: String] = [:]) {
        self.binary = binary
        self.timeout = timeout
        self.extraEnvironment = extraEnvironment
        self.logger = Logger(subsystem: BuildInfo.osLogSubsystem, category: "runner")
    }

    func run(arguments: [String]) async throws -> RunResult {
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw RunnerError.binaryNotExecutable(binary)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.qualityOfService = .userInitiated
        if !extraEnvironment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in extraEnvironment { env[k] = v }
            process.environment = env
        }

        logger.debug("spawn: \(binary.path, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RunResult, Error>) in
                process.terminationHandler = { proc in
                    let stdoutData = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
                    let stderrData = (try? stderr.fileHandleForReading.readToEnd()) ?? Data()
                    let stderrTail = Self.tail(of: stderrData, lines: 8)

                    self.logger.debug("exit: \(proc.terminationStatus) stderr: \(stderrTail, privacy: .public)")

                    switch proc.terminationStatus {
                    case 0:
                        guard let jsonLine = Self.lastJSONLine(in: stdoutData) else {
                            continuation.resume(throwing: RunnerError.malformedJSON)
                            return
                        }
                        do {
                            let result = try JSONDecoder().decode(RunResult.self, from: jsonLine)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: RunnerError.malformedJSON)
                        }
                    case 1:
                        continuation.resume(throwing: RunnerError.userError(stderrTail: stderrTail))
                    case 2:
                        continuation.resume(throwing: RunnerError.noSubject)
                    case 3:
                        continuation.resume(throwing: RunnerError.framework(stderrTail: stderrTail))
                    default:
                        // SIGTERM (15) from cancellation surfaces as 143; anything else is framework.
                        if proc.terminationStatus == 143 || proc.terminationReason == .uncaughtSignal {
                            continuation.resume(throwing: RunnerError.cancelled)
                        } else {
                            continuation.resume(throwing: RunnerError.framework(stderrTail: stderrTail))
                        }
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: RunnerError.framework(stderrTail: error.localizedDescription))
                }
            }
        } onCancel: {
            // Cooperatively terminate. The handler above maps the resulting exit code.
            if process.isRunning {
                process.terminate()
            }
        }
    }

    /// Find the last JSON object in stdout. bgbgone normally emits a single line but
    /// could in theory print log noise before it on misconfigured installs.
    private static func lastJSONLine(in data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lastObjectLine = text
            .split(whereSeparator: \.isNewline)
            .reversed()
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") })
        return lastObjectLine.flatMap { String($0).data(using: .utf8) }
    }

    private static func tail(of data: Data, lines: Int) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return "" }
        let split = text.split(whereSeparator: \.isNewline)
        return split.suffix(lines).joined(separator: "\n")
    }
}
