import Foundation
import Testing
@testable import bgbgone_app

@Suite("TrashService (T6)")
struct TrashServiceTests {
    @Test func trashingMovesFileToTrashAndReturnsURL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrashServiceTests-\(UUID().uuidString).txt")
        try "hello".write(to: tmp, atomically: true, encoding: .utf8)

        let resulting = try TrashService.trash(tmp)

        #expect(!FileManager.default.fileExists(atPath: tmp.path))
        #expect(resulting != nil)
        #expect(resulting?.path.contains(".Trash") == true)
    }

    @Test func trashingMissingFileReturnsNilWithoutThrowing() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrashServiceTests-missing-\(UUID().uuidString).txt")
        let resulting = try TrashService.trash(missing)
        #expect(resulting == nil)
    }
}
