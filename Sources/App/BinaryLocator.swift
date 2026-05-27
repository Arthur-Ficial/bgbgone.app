import Foundation
import os

/// Locates the `bgbgone` CLI binary at runtime — **bundled-only, no fallback**.
///
/// Resolution order (see the project's CLAUDE.md):
///   1. `~/Library/Application Support/bgbgone-app/settings.json` override path
///      (opt-in; the documented dev/test escape hatch — defaults to absent).
///   2. `Bundle.main` → `Contents/Helpers/bgbgone` — the version-locked binary the
///      app shipped and was tested against.
///
/// There is **deliberately no PATH / Homebrew / `/usr/local` scavenging**: a stale
/// user-installed `bgbgone` (e.g. an ancient v0.1.x) must never shadow the pinned,
/// bundled binary and break the version-coupled argv/JSON contract. If neither the
/// override nor the bundled helper resolves, the app shows `MissingBinaryView` and
/// disables actions — it does not fall back to "whatever's on the machine".
///
/// Logs the resolved path via `OSLog` so agents can see which copy is actually running.
struct BinaryLocator: Sendable {
    enum LocatorError: Error, Equatable, Sendable {
        case notFound(searched: [String])
        case overrideNotExecutable(URL)
    }

    /// Closure that returns `true` when the given path is an executable file.
    /// Production wires this to `FileManager.default.isExecutableFile(atPath:)`;
    /// tests inject a set-membership lookup for deterministic behaviour.
    let isExecutable: @Sendable (String) -> Bool
    let bundleHelpersDir: URL?
    let overridePath: URL?

    /// Production initialiser — reads the main bundle + on-disk override.
    init() {
        self.init(
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) },
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
        bundleHelpersDir: URL?,
        overridePath: URL?
    ) {
        self.isExecutable = isExecutable
        self.bundleHelpersDir = bundleHelpersDir
        self.overridePath = overridePath
    }

    func locate() throws -> URL {
        let logger = Logger(subsystem: BuildInfo.osLogSubsystem, category: "binary")
        var searched: [String] = []

        // 1. Explicit override (opt-in dev/test escape hatch).
        if let override = overridePath {
            guard isExecutable(override.path) else {
                throw LocatorError.overrideNotExecutable(override)
            }
            logger.info("resolved (override): \(override.path, privacy: .public)")
            return override
        }

        // 2. Bundled, version-locked helper — the only production path.
        if let helpersDir = bundleHelpersDir {
            let bundled = helpersDir.appendingPathComponent("bgbgone")
            searched.append(bundled.path)
            if isExecutable(bundled.path) {
                logger.info("resolved (bundled): \(bundled.path, privacy: .public)")
                return bundled
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
