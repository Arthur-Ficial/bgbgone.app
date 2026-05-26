import Foundation
import os

/// Locates the `bgbgone` CLI binary at runtime.
///
/// Resolution order (user-chosen, see the project's CLAUDE.md):
///   1. `~/Library/Application Support/bgbgone-app/settings.json` override path
///   2. `Bundle.main` → `Contents/Helpers/bgbgone` — the version-locked binary the
///      app shipped and was tested against. Preferred so a stale user-installed
///      bgbgone on PATH/Homebrew (e.g. an ancient v0.1.x) can't shadow it and break
///      the version-coupled argv contract.
///   3. `PATH` lookup
///   4. `/opt/homebrew/bin/bgbgone`
///   5. `/usr/local/bin/bgbgone`
///
/// Steps 3–5 are the fallback for dev runs (`swift run` with no `.app` bundle, so no
/// embedded helper). First hit that is `isExecutableFile` wins. Logs the resolved
/// path via `OSLog` so agents can see which copy is actually running.
struct BinaryLocator: Sendable {
    enum LocatorError: Error, Equatable, Sendable {
        case notFound(searched: [String])
        case overrideNotExecutable(URL)
    }

    /// Closure that returns `true` when the given path is an executable file.
    /// Production wires this to `FileManager.default.isExecutableFile(atPath:)`;
    /// tests inject a set-membership lookup for deterministic behaviour.
    let isExecutable: @Sendable (String) -> Bool
    let environment: [String: String]
    let homebrewBin: URL
    let usrLocalBin: URL
    let bundleHelpersDir: URL?
    let overridePath: URL?

    /// Production initialiser — reads env + main bundle + on-disk override.
    init() {
        self.init(
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
            environment: ProcessInfo.processInfo.environment,
            homebrewBin: URL(fileURLWithPath: "/opt/homebrew/bin/bgbgone"),
            usrLocalBin: URL(fileURLWithPath: "/usr/local/bin/bgbgone"),
            bundleHelpersDir: Bundle.main.executableURL?
                .deletingLastPathComponent() // …/Contents/MacOS
                .deletingLastPathComponent() // …/Contents
                .appendingPathComponent("Helpers"),
            overridePath: Self.readOverridePath()
        )
    }

    /// Test-friendly initialiser. Tests inject explicit paths to assert each branch
    /// without depending on the machine's actual filesystem.
    init(
        isExecutable: @escaping @Sendable (String) -> Bool,
        environment: [String: String],
        homebrewBin: URL,
        usrLocalBin: URL,
        bundleHelpersDir: URL?,
        overridePath: URL?
    ) {
        self.isExecutable = isExecutable
        self.environment = environment
        self.homebrewBin = homebrewBin
        self.usrLocalBin = usrLocalBin
        self.bundleHelpersDir = bundleHelpersDir
        self.overridePath = overridePath
    }

    func locate() throws -> URL {
        let logger = Logger(subsystem: BuildInfo.osLogSubsystem, category: "binary")
        var searched: [String] = []

        // 1. Explicit override
        if let override = overridePath {
            guard isExecutable(override.path) else {
                throw LocatorError.overrideNotExecutable(override)
            }
            logger.info("resolved (override): \(override.path, privacy: .public)")
            return override
        }

        // 2. Bundle-embedded binary — the version-locked copy this app build was
        // tested against. Checked before PATH so a stale user-installed bgbgone
        // can't shadow it and break the argv contract.
        if let helpersDir = bundleHelpersDir {
            let bundled = helpersDir.appendingPathComponent("bgbgone")
            searched.append(bundled.path)
            if isExecutable(bundled.path) {
                logger.info("resolved (bundled): \(bundled.path, privacy: .public)")
                return bundled
            }
        }

        // 3. PATH (only entries the env actually advertises) — dev-run fallback when
        // there is no `.app` bundle to embed the helper.
        let pathDirs = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        for dir in pathDirs {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent("bgbgone")
            searched.append(candidate.path)
            if isExecutable(candidate.path) {
                logger.info("resolved (PATH): \(candidate.path, privacy: .public)")
                return candidate
            }
        }

        // 4 + 5. Well-known Homebrew / /usr/local prefixes (in case PATH isn't inherited
        // under launchd or the user installed via `make install` outside their shell PATH).
        for candidate in [homebrewBin, usrLocalBin] {
            searched.append(candidate.path)
            if isExecutable(candidate.path) {
                logger.info("resolved (well-known): \(candidate.path, privacy: .public)")
                return candidate
            }
        }

        logger.error("bgbgone not found — searched: \(searched.joined(separator: ", "), privacy: .public)")
        throw LocatorError.notFound(searched: searched)
    }

    // MARK: - Override persistence

    private static let supportDir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("bgbgone-app", isDirectory: true)
    private static let settingsURL = supportDir?.appendingPathComponent("settings.json")

    private struct Settings: Codable {
        var binaryOverridePath: String?
    }

    static func readOverridePath() -> URL? {
        guard let settingsURL,
              FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(Settings.self, from: data),
              let path = settings.binaryOverridePath, !path.isEmpty
        else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Persist (or clear) the override path. Called from the `--debug` Tweaks panel.
    static func writeOverridePath(_ url: URL?) throws {
        guard let supportDir, let settingsURL else { return }
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let settings = Settings(binaryOverridePath: url?.path)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }
}
