import SwiftUI

/// T14 — power-user free-form `--filter` editor. When non-empty, overrides the
/// composed chain from the GUI controls. Live-validates via `FilterChainParser` and
/// shows the live composed chain (from GUI controls) for reference.
struct AdvancedChainEditor: View {
    @Bindable var viewModel: AppViewModel
    @State private var isExpanded: Bool = false
    @State private var parseError: String? = nil

    private var textBinding: Binding<String> {
        Binding(
            get: { viewModel.config.advancedFilterText ?? "" },
            set: { newValue in
                viewModel.config.advancedFilterText = newValue.isEmpty ? nil : newValue
                validate(newValue)
            }
        )
    }

    var body: some View {
        DisclosureGroup("Advanced — full filter chain", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Override the GUI controls with a hand-written `--filter` chain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "e.g. mask:feather=8;fg:outline=color=#fff:width=3;bg:grayscale",
                    text: textBinding,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .lineLimit(3...6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(
                        parseError == nil ? Color.clear : Color.red, lineWidth: 1
                    )
                )

                if let err = parseError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                let composed = viewModel.config.filterChain.dslString
                if !composed.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Composed from GUI controls (used when text above is empty):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(composed)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func validate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { parseError = nil; return }
        do {
            _ = try FilterChainParser.parse(trimmed)
            parseError = nil
        } catch FilterChainParser.ParseError.unknownLayer(let layer) {
            parseError = "Unknown layer '\(layer)' — use fg, bg, mask, or all."
        } catch FilterChainParser.ParseError.emptyFilterName {
            parseError = "Empty filter name — each stage needs a filter."
        } catch {
            parseError = "Parse error: \(error)"
        }
    }
}
