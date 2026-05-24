import Foundation
import Testing
@testable import bgbgone_app

@Suite("RunHistoryStore persistence")
struct RunHistoryStoreTests {
    static func makeTempDirectory(name: StaticString = #function) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RunHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func sampleEntry(outputName: String = "anna_bgbgone.png") -> RunHistoryEntry {
        RunHistoryEntry(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1000),
            finishedAt: Date(timeIntervalSince1970: 1002),
            durationMillis: 2000,
            outputURL: URL(fileURLWithPath: "/tmp/cutouts/\(outputName)"),
            outcome: .success,
            configSnapshot: .init(
                outDirectory: URL(fileURLWithPath: "/tmp/cutouts"),
                namePattern: "{name}_bgbgone",
                background: .transparent,
                format: .png,
                filterChain: ""
            )
        )
    }

    @Test func writesAndLoadsEntriesPerFile() async throws {
        let dir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileA = UUID()
        let fileB = UUID()
        let entryA = Self.sampleEntry(outputName: "a.png")
        let entryB = Self.sampleEntry(outputName: "b.png")

        let store = RunHistoryStore(directory: dir)
        await store.append(entryA, for: fileA)
        await store.append(entryB, for: fileB)
        try await store.flush()

        let reloaded = RunHistoryStore(directory: dir)
        await reloaded.load()
        let aEntries = await reloaded.entries(for: fileA)
        let bEntries = await reloaded.entries(for: fileB)
        #expect(aEntries == [entryA])
        #expect(bEntries == [entryB])
    }

    @Test func appendsMultipleEntriesInOrder() async throws {
        let dir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileID = UUID()
        let first = Self.sampleEntry(outputName: "first.png")
        let second = Self.sampleEntry(outputName: "second.png")

        let store = RunHistoryStore(directory: dir)
        await store.append(first, for: fileID)
        await store.append(second, for: fileID)
        try await store.flush()

        let reloaded = RunHistoryStore(directory: dir)
        await reloaded.load()
        #expect(await reloaded.entries(for: fileID) == [first, second])
    }

    @Test func loadAndPruneDropsOrphans() async throws {
        let dir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let known = UUID()
        let orphan = UUID()

        let store = RunHistoryStore(directory: dir)
        await store.append(Self.sampleEntry(outputName: "known.png"), for: known)
        await store.append(Self.sampleEntry(outputName: "orphan.png"), for: orphan)
        try await store.flush()

        let reloaded = RunHistoryStore(directory: dir)
        await reloaded.loadAndPrune(knownFileIDs: [known])

        #expect(await reloaded.entries(for: known).count == 1)
        #expect(await reloaded.entries(for: orphan).isEmpty)
    }

    @Test func emptyDirectoryLoadsAsEmpty() async {
        let dir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RunHistoryStore(directory: dir)
        await store.load()
        #expect(await store.entries(for: UUID()).isEmpty)
    }
}
