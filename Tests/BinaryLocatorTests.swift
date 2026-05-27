import Foundation
import Testing
@testable import bgbgone_app

@Suite("BinaryLocator (bundled-only)")
struct BinaryLocatorTests {
    static let defaultHelpers = URL(fileURLWithPath: "/Applications/bgbgone-app.app/Contents/Helpers")

    /// One executable-path set per test — `isExecutable` returns true iff the queried
    /// path is in the set. Lets each test pin which lookup step "succeeds".
    static func locator(
        executablePaths: Set<String> = [],
        bundleHelpersDir: URL? = defaultHelpers,
        overridePath: URL? = nil
    ) -> BinaryLocator {
        BinaryLocator(
            isExecutable: { executablePaths.contains($0) },
            bundleHelpersDir: bundleHelpersDir,
            overridePath: overridePath
        )
    }

    @Test func overrideWins() throws {
        let override = URL(fileURLWithPath: "/tmp/custom/bgbgone")
        let bundled = Self.defaultHelpers.appendingPathComponent("bgbgone")
        let locator = Self.locator(
            executablePaths: [override.path, bundled.path],
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

    @Test func bundledResolves() throws {
        let bundled = Self.defaultHelpers.appendingPathComponent("bgbgone")
        let locator = Self.locator(executablePaths: [bundled.path])
        #expect(try locator.locate() == bundled)
    }

    /// The whole point of bundled-only: a stale `bgbgone` installed on PATH / Homebrew /
    /// `/usr/local` must NOT be resolved. With no override and no bundled helper, locate
    /// throws `.notFound` even though system copies are "executable".
    @Test func staleSystemBinaryIsIgnored() {
        let locator = Self.locator(
            executablePaths: [
                "/opt/homebrew/bin/bgbgone",
                "/usr/local/bin/bgbgone",
                "/usr/bin/bgbgone",
            ],
            bundleHelpersDir: Self.defaultHelpers // present, but no bgbgone inside it
        )
        #expect(throws: BinaryLocator.LocatorError.self) {
            try locator.locate()
        }
    }

    @Test func nothingFoundThrowsWithOnlyBundledSearched() throws {
        let locator = Self.locator(executablePaths: [])
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
        // Only the bundled helper path is ever searched — no PATH/Homebrew/usr-local.
        #expect(searched == [Self.defaultHelpers.appendingPathComponent("bgbgone").path])
    }
}
