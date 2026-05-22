import Foundation

/// Background choice — maps to bgbgone's `--bg` flag.
enum BackgroundChoice: Sendable, Hashable {
    case transparent
    case color(hex: String)
    case image(URL)
}

/// Output format — maps to bgbgone's `--to` flag.
enum OutputFormat: String, Sendable, Hashable, CaseIterable, Codable {
    case png, jpg, heic, tiff

    /// CLI argument value (`--to png`, etc.).
    var cliValue: String { rawValue }

    /// File extension to append to the resolved output path.
    var fileExtension: String { rawValue }

    /// Display label as rendered in the design's ConfigPanel radio chips.
    var displayLabel: String {
        switch self {
        case .png: "PNG"
        case .jpg: "JPEG"
        case .heic: "HEIC"
        case .tiff: "TIFF"
        }
    }
}

/// User-configurable settings. Owned by `AppViewModel`, persisted via `UserDefaults`.
/// One `Config` applies uniformly to every queued file (per-file overrides land in v0.2).
struct Config: Sendable, Hashable {
    /// Absolute output directory (must exist and be writable).
    var outDirectory: URL

    /// Filename template — supports `{name}`, `{ext}`, `{n}`, `{n:02}`, `{n:NN}` tokens.
    /// Default matches the design: `{name}_bgbgone`.
    var namePattern: String = "{name}_bgbgone"

    var background: BackgroundChoice = .transparent
    var format: OutputFormat = .png

    /// 5 swatches from `design/project/app.jsx:COLOR_PRESETS`. Used by the UI; not part
    /// of the argv computation but lives here so the rest of the app reads one config.
    static let colorPresets: [String] = ["#ffffff", "#000000", "#0066cc", "#f06a3a", "#2da94f"]

    /// Default Pictures-relative folder used on first launch.
    static var defaultOutDirectory: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("cutouts", isDirectory: true)
    }
}
