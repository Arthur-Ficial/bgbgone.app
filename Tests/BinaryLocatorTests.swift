import Foundation
import Testing
@testable import bgbgone_app

@Suite("BinaryLocator")
struct BinaryLocatorTests {
    /// One executable-path set per test — `isExecutable` returns true iff the queried
    /// path is in the set. Lets each test pin which lookup step "succeeds".
    static func locator(
        executablePaths: Set<String> = [],
        environment: [String: String] = [:],
        bundleHelpersDir: URL? = URL(fileURLWithPath: "/Applications/bgbgone-app.app/Contents/Helpers"),
        overridePath: URL? = nil
    ) -> BinaryLocator {
        BinaryLocator(
            isExecutable: { executablePaths.contains($0) },
            environment: environment,
            homebrewBin: URL(fileURLWithPath: "/opt/homebrew/bin/bgbgone"),
            usrLocalBin: URL(fileURLWithPath: "/usr/local/bin/bgbgone"),
            bundleHelpersDir: bundleHelpersDir,
            overridePath: overridePath
        )
    }

    @Test func overrideWins() throws {
        let override = URL(fileURLWithPath: "/tmp/custom/bgbgone")
        let locator = Self.locator(
            executablePaths: [override.path, "/opt/homebrew/bin/bgbgone"],
            environment: ["PATH": "/opt/homebrew/bin"],
            overridePath: override
        )
        #expect(try locator.locate() == override)
    }

    @Test func overrideMustBeExecutable() {
        let override = URL(fileURLWithPath: "/tmp/missing/bgbgone")
        let locator = Self.locator(overridePath: override)
        #expect(throws: BinaryLocator.LocatorError.overrideNotExecutable(override)) {
            try locator.locate()
        }
    }

    @Test func pathLookupHit() throws {
        let locator = Self.locator(
            executablePaths: ["/usr/bin/bgbgone"],
            environment: ["PATH": "/sbin:/usr/bin:/opt/homebrew/bin"]
        )
        #expect(try locator.locate() == URL(fileURLWithPath: "/usr/bin/bgbgone"))
    }

    @Test func homebrewFallback() throws {
        // PATH doesn't have homebrew but the binary's there anyway (launchd case).
        let locator = Self.locator(
            executablePaths: ["/opt/homebrew/bin/bgbgone"],
            environment: ["PATH": "/sbin:/bin"]
        )
        #expect(try locator.locate() == URL(fileURLWithPath: "/opt/homebrew/bin/bgbgone"))
    }

    @Test func usrLocalBinFallback() throws {
        let locator = Self.locator(
            executablePaths: ["/usr/local/bin/bgbgone"],
            environment: [:]
        )
        #expect(try locator.locate() == URL(fileURLWithPath: "/usr/local/bin/bgbgone"))
    }

    @Test func bundledFallback() throws {
        let helpers = URL(fileURLWithPath: "/Applications/bgbgone-app.app/Contents/Helpers")
        let bundled = helpers.appendingPathComponent("bgbgone")
        let locator = Self.locator(
            executablePaths: [bundled.path],
            bundleHelpersDir: helpers
        )
        #expect(try locator.locate() == bundled)
    }

    @Test func bundledBeatsPathAndHomebrew() throws {
        // The app's argv is version-coupled to the bgbgone it ships. A stale
        // user-installed copy on PATH/Homebrew (e.g. an ancient v0.1.x) must NOT
        // shadow the version-locked binary embedded in the bundle. Only an explicit
        // settings.json override may win over the bundled binary.
        let helpers = URL(fileURLWithPath: "/Applications/bgbgone-app.app/Contents/Helpers")
        let bundled = helpers.appendingPathComponent("bgbgone")
        let locator = Self.locator(
            executablePaths: [
                bundled.path,
                "/usr/bin/bgbgone",
                "/opt/homebrew/bin/bgbgone",
                "/usr/local/bin/bgbgone",
            ],
            environment: ["PATH": "/usr/bin:/opt/homebrew/bin"],
            bundleHelpersDir: helpers
        )
        #expect(try locator.locate() == bundled)
    }

    @Test func nothingFoundThrows() throws {
        let locator = Self.locator(
            executablePaths: [],
            environment: ["PATH": "/sbin:/bin"]
        )
        var caught: BinaryLocator.LocatorError?
        do {
            _ = try locator.locate()
        } catch let error as BinaryLocator.LocatorError {
            caught = error
        }
        guard case .notFound(let searched) = caught else {
            Issue.record("expected .notFound, got \(String(describing: caught))")
            return
        }
        // PATH dirs + homebrew + usrLocal + bundled = at least 5 candidates checked.
        #expect(searched.count >= 4)
        #expect(searched.contains("/opt/homebrew/bin/bgbgone"))
        #expect(searched.contains("/usr/local/bin/bgbgone"))
    }
}
