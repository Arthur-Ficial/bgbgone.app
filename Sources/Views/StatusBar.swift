import SwiftUI

/// 28px status strip at the bottom of the window.
struct StatusBar: View {
    let viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 14) {
            if viewModel.files.count > 0 {
                HStack(spacing: 4) {
                    Text("\(doneCount)").bold().monospacedDigit()
                    Text("of \(viewModel.files.count) done")
                    if errorCount > 0 {
                        Text(",")
                        Text("\(errorCount)").bold().foregroundStyle(.red)
                        Text("failed")
                    }
                }
            } else {
                Text("No images yet")
            }
            Spacer()
            Text("→ \(samplePreviewPath)")
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 28)
        .frame(height: 28)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 1)
        }
    }

    private var doneCount: Int {
        viewModel.files.lazy.filter { if case .done = $0.state { return true } else { return false } }.count
    }

    private var errorCount: Int {
        viewModel.files.lazy.filter { if case .error = $0.state { return true } else { return false } }.count
    }

    private var samplePreviewPath: String {
        let dir = viewModel.config.outDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let sample = viewModel.files.first?.url
        let stem = sample.map { ($0.lastPathComponent as NSString).deletingPathExtension } ?? "{name}"
        let expandedPattern = viewModel.config.namePattern.replacingOccurrences(of: "{name}", with: stem)
        return "\(dir)/\(expandedPattern).\(viewModel.config.format.fileExtension)"
    }
}
