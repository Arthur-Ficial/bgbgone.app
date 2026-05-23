import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Finder/System-Settings-style `Form` panel. Stock `Picker` / `TextField` / `ColorPicker`
/// / `.fileImporter`. Lives in the inspector column on the right side of the window.
struct ConfigPanel: View {
    @Bindable var viewModel: AppViewModel
    @State private var folderImporterShown = false
    @State private var imageImporterShown = false
    @State private var colourBinding: Color = .white

    var body: some View {
        Form {
            Section("Save to") {
                HStack {
                    Label(displayPath, systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") { folderImporterShown = true }
                }
            }

            Section("Name as") {
                TextField("Filename pattern", text: $viewModel.config.namePattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                HStack(spacing: 6) {
                    ForEach(["{name}", "{ext}", "{n:02}"], id: \.self) { token in
                        Button(token) { viewModel.config.namePattern += token }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }

            Section("Background") {
                Picker("", selection: backgroundCase) {
                    Text("Transparent").tag(BackgroundCase.transparent)
                    Text("Color").tag(BackgroundCase.color)
                    Text("Image").tag(BackgroundCase.image)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if case .color = viewModel.config.background {
                    ColorPicker("Colour", selection: $colourBinding, supportsOpacity: false)
                        .onChange(of: colourBinding) { _, new in
                            viewModel.config.background = .color(hex: new.toHex() ?? "#ffffff")
                        }
                }
                if case .image(let url) = viewModel.config.background {
                    HStack {
                        Label(url.lastPathComponent, systemImage: "photo")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Change…") { imageImporterShown = true }
                    }
                }
            }

            Section("Format") {
                Picker("", selection: $viewModel.config.format) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayLabel).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $folderImporterShown,
            allowedContentTypes: [.folder],
            onCompletion: handleFolderPick
        )
        .fileImporter(
            isPresented: $imageImporterShown,
            allowedContentTypes: [.png, .jpeg, .heic, .tiff],
            onCompletion: handleImagePick
        )
        .onAppear(perform: syncColourFromBackground)
    }

    private var displayPath: String {
        viewModel.config.outDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    /// Bridge `BackgroundChoice` (associated values) ↔ `Picker` (needs a `Hashable` tag).
    private var backgroundCase: Binding<BackgroundCase> {
        Binding(
            get: {
                switch viewModel.config.background {
                case .transparent: .transparent
                case .color: .color
                case .image: .image
                }
            },
            set: { newCase in
                switch newCase {
                case .transparent:
                    viewModel.config.background = .transparent
                case .color:
                    let hex = colourBinding.toHex() ?? "#ffffff"
                    viewModel.config.background = .color(hex: hex)
                case .image:
                    // We can't pick a URL synchronously from the segmented control —
                    // open the importer; until the user picks something, stay on the
                    // last image URL we had, or fall back to transparent.
                    if case .image = viewModel.config.background {
                        imageImporterShown = true
                    } else {
                        imageImporterShown = true
                    }
                }
            }
        )
    }

    private func handleFolderPick(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            viewModel.config.outDirectory = url
        }
    }

    private func handleImagePick(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            viewModel.config.background = .image(url)
        }
    }

    private func syncColourFromBackground() {
        if case .color(let hex) = viewModel.config.background {
            colourBinding = Color(hex: hex)
        }
    }
}

private enum BackgroundCase: Hashable { case transparent, color, image }

/// `Color` → `#rrggbb` for storage in `Config.background.color`.
private extension Color {
    func toHex() -> String? {
        let ns = NSColor(self).usingColorSpace(.sRGB)
        guard let r = ns?.redComponent, let g = ns?.greenComponent, let b = ns?.blueComponent else {
            return nil
        }
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
