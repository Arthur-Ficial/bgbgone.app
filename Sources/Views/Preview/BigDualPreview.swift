import SwiftUI

/// T12: dual preview strip pinned to the top of the middle column (out of the right
/// inspector). Two equal panes side by side, corner labels only (no filename / dim /
/// duration text overlay — those live in the file list and inspector meta strip).
///
/// When nothing is selected, both panes render their corner label over the empty
/// state — same as Finder's preview pane behaviour.
struct BigDualPreview: View {
    let viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 14) {
            previewPane(label: "ORIGINAL", url: originalURL)
            previewPane(label: "CUTOUT", url: cutoutURL)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var selectedFile: ImageFile? {
        viewModel.files.first(where: { $0.id == viewModel.selectedId })
    }

    private var originalURL: URL? { selectedFile?.url }

    private var cutoutURL: URL? {
        guard let file = selectedFile else { return nil }
        guard case .done = file.state else { return nil }
        return BgBgOneCommand.resolveOutputURL(
            for: file.url,
            in: viewModel.config.outDirectory,
            pattern: viewModel.config.namePattern,
            format: viewModel.config.format
        )
    }

    @ViewBuilder
    private func previewPane(label: String, url: URL?) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05))
                )
            if let url, FileManager.default.fileExists(atPath: url.path) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().controlSize(.small)
                }
                .padding(10)
            }
            cornerLabel(label)
        }
    }

    private func cornerLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold).smallCaps())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
            .padding(8)
    }
}
