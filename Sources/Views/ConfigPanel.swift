import SwiftUI
import AppKit

/// Two-column grid panel: Save to / Name as / Background / Format.
struct ConfigPanel: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 11) {
            GridRow {
                Label("Save to")
                FolderPicker(directory: $viewModel.config.outDirectory)
                    .gridCellAnchor(.leading)
            }

            GridRow {
                Label("Name as")
                NamePatternField(pattern: $viewModel.config.namePattern)
                    .gridCellAnchor(.leading)
            }

            GridRow {
                Label("Background")
                BackgroundChips(background: $viewModel.config.background)
                    .gridCellAnchor(.leading)
            }

            GridRow {
                Label("Format")
                FormatChips(format: $viewModel.config.format)
                    .gridCellAnchor(.leading)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 22)
    }
}

private struct Label: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(DesignFont.label)
            .foregroundStyle(DesignColor.fgMute)
            .frame(width: 80, alignment: .leading)
    }
}

private struct FolderPicker: View {
    @Binding var directory: URL

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(DesignColor.fgFaint)
                Text(directory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(DesignFont.mono)
                    .foregroundStyle(DesignColor.fg)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .buttonStyle(.plain)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url { directory = url }
    }
}

private struct NamePatternField: View {
    @Binding var pattern: String

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $pattern)
                .textFieldStyle(.plain)
                .font(DesignFont.mono)
                .foregroundStyle(DesignColor.fg)
                .frame(maxWidth: 240)

            HStack(spacing: 4) {
                ForEach(["{name}", "{ext}", "{n:02}"], id: \.self) { token in
                    Button(token) { pattern += token }
                        .buttonStyle(TokenChipStyle())
                }
            }
        }
    }
}

private struct TokenChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(DesignColor.fgMute)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed
                          ? Color(white: 0.88)
                          : DesignColor.bgSoft)
            )
    }
}

private struct BackgroundChips: View {
    @Binding var background: BackgroundChoice

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                RadioChip(label: "Transparent",
                          isActive: isTransparent,
                          leading: { CheckerSwatch() }) {
                    background = .transparent
                }
                RadioChip(label: "Color",
                          isActive: isColor,
                          leading: { ColorSwatchPreview(color: colorValue) }) {
                    if !isColor { background = .color(hex: colorValue) }
                }
                RadioChip(label: "Image…",
                          isActive: isImage,
                          leading: { EmptyView() }) {
                    chooseImage()
                }
            }
            if isColor {
                ColorPickerInline(hex: Binding(
                    get: { colorValue },
                    set: { background = .color(hex: $0) }
                ))
            }
        }
    }

    private var isTransparent: Bool {
        if case .transparent = background { return true }; return false
    }
    private var isColor: Bool {
        if case .color = background { return true }; return false
    }
    private var isImage: Bool {
        if case .image = background { return true }; return false
    }
    private var colorValue: String {
        if case .color(let hex) = background { return hex }
        return "#ffffff"
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        if panel.runModal() == .OK, let url = panel.url { background = .image(url) }
    }
}

private struct RadioChip<Leading: View>: View {
    let label: String
    let isActive: Bool
    @ViewBuilder let leading: () -> Leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leading()
                Text(label).font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? DesignColor.accentPress : DesignColor.fgMute)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? DesignColor.bgSelected : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CheckerSwatch: View {
    var body: some View {
        Canvas { ctx, size in
            let t: CGFloat = 3
            for r in 0...3 {
                for c in 0...3 {
                    let isLight = (r + c).isMultiple(of: 2)
                    ctx.fill(
                        Path(CGRect(x: CGFloat(c) * t, y: CGFloat(r) * t, width: t, height: t)),
                        with: .color(isLight ? .white : Color(white: 0.75))
                    )
                }
            }
        }
        .frame(width: 12, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.1)))
    }
}

private struct ColorSwatchPreview: View {
    let color: String
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: color))
            .frame(width: 12, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.1)))
    }
}

private struct ColorPickerInline: View {
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Config.colorPresets, id: \.self) { preset in
                Button(action: { hex = preset }) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: preset))
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(hex == preset ? DesignColor.accent : DesignColor.border,
                                              lineWidth: hex == preset ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
            TextField("", text: $hex)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 100, height: 26)
                .padding(.horizontal, 8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(DesignColor.border))
        }
    }
}

private struct FormatChips: View {
    @Binding var format: OutputFormat
    var body: some View {
        HStack(spacing: 2) {
            ForEach(OutputFormat.allCases, id: \.self) { f in
                RadioChip(label: f.displayLabel, isActive: format == f, leading: { EmptyView() }) {
                    format = f
                }
            }
        }
    }
}
