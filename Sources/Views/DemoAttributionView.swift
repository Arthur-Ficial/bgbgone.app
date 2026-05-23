import SwiftUI
import Foundation

/// Sheet shown on Demo Mode launch. Lists every image's source URL + license so the
/// user (and any reviewer / legal) sees the attribution before the demo runs.
struct DemoAttributionView: View {
    let manifest: DemoManifest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo Mode — 10 public-domain images")
                        .font(.title3.weight(.semibold))
                    Text("From Wikimedia Commons. Real downloads on first run; cached in \(cacheDirDisplay).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            List(manifest.images) { image in
                VStack(alignment: .leading, spacing: 2) {
                    Text(image.filename)
                        .font(.body.monospaced())
                    Text(image.subject)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(image.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(image.license)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                        Link(image.url, destination: URL(string: image.url)!)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Text("By continuing you'll download ~5 MB to your cache and run them through bgbgone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Download & Run") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 540)
    }

    private var cacheDirDisplay: String {
        "~/Library/Caches/bgbgone-app/demo/"
    }
}

/// JSON shape of `scripts/demo-manifest.json`. Lives in Sources/ so the GUI can parse
/// it once at startup; the script and the GUI share this exact contract.
struct DemoManifest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let notes: String
    let images: [Image]

    struct Image: Codable, Hashable, Identifiable, Sendable {
        var id: String { filename }
        let filename: String
        let url: String
        let license: String
        let attribution: String
        let subject: String
        let exercises: String
    }

    /// Load from the bundled scripts directory. Returns nil if the file is missing or
    /// can't be parsed (real-world: someone deleted it from the bundle).
    static func loadFromBundle() -> DemoManifest? {
        guard let url = manifestURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DemoManifest.self, from: data)
    }

    /// Resolve `scripts/demo-manifest.json` next to the `bgbgone` helper in the bundle,
    /// or — when run from `swift run` — relative to the package root.
    static func manifestURL() -> URL? {
        let bundleScripts = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/scripts/demo-manifest.json")
        if FileManager.default.fileExists(atPath: bundleScripts.path) { return bundleScripts }

        // Dev mode (`swift run` from package root): scripts/ sits at the repo root.
        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/demo-manifest.json")
        if FileManager.default.fileExists(atPath: dev.path) { return dev }

        return nil
    }

    static func scriptURL() -> URL? {
        let bundleScripts = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/scripts/fetch-demo-images.sh")
        if FileManager.default.fileExists(atPath: bundleScripts.path) { return bundleScripts }

        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/fetch-demo-images.sh")
        if FileManager.default.fileExists(atPath: dev.path) { return dev }

        return nil
    }
}
