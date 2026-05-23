import Foundation
import Testing
@testable import bgbgone_app

/// `scripts/demo-manifest.json` is the contract between the GUI's Demo Mode flow and
/// the bash fetch script. If this test fails, one of them is reading a shape the other
/// didn't write.
@Suite("Demo manifest contract")
struct DemoManifestTests {
    static var manifestURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("scripts/demo-manifest.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: "/dev/null/demo-manifest.json")
    }

    @Test func manifestParsesAndHasTenImages() throws {
        let data = try Data(contentsOf: Self.manifestURL)
        let manifest = try JSONDecoder().decode(DemoManifest.self, from: data)
        #expect(manifest.images.count == 10, "expected 10 demo images, got \(manifest.images.count)")
        #expect(manifest.schemaVersion >= 1)
    }

    @Test func everyImageHasAllRequiredKeys() throws {
        let data = try Data(contentsOf: Self.manifestURL)
        let manifest = try JSONDecoder().decode(DemoManifest.self, from: data)
        for image in manifest.images {
            #expect(!image.filename.isEmpty, "empty filename in manifest entry")
            #expect(image.url.hasPrefix("https://"), "non-https url in entry \(image.filename): \(image.url)")
            #expect(!image.license.isEmpty, "missing license in entry \(image.filename)")
            #expect(!image.attribution.isEmpty, "missing attribution in entry \(image.filename)")
            #expect(URL(string: image.url) != nil, "malformed url in entry \(image.filename)")
        }
    }

    @Test func filenamesAreUnique() throws {
        let data = try Data(contentsOf: Self.manifestURL)
        let manifest = try JSONDecoder().decode(DemoManifest.self, from: data)
        let names = manifest.images.map(\.filename)
        #expect(Set(names).count == names.count, "duplicate filenames in demo manifest: \(names)")
    }
}
