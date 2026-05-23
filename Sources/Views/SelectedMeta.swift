import SwiftUI

/// Strip below DualPreview in the inspector: filename + dims/bytes/ms + status pill.
/// System fonts and semantic colours throughout.
struct SelectedMeta: View {
    let file: ImageFile?

    var body: some View {
        if let file {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(file.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(metaLine(for: file))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()

                StatusPill(state: file.state)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func metaLine(for file: ImageFile) -> String {
        var parts: [String] = []
        if let w = file.width, let h = file.height {
            parts.append("\(w) × \(h)")
        }
        if let bytes = file.bytes {
            parts.append(Self.humanBytes(bytes))
        }
        if case .done(let ms) = file.state, ms > 0 {
            parts.append("removed in \(ms) ms")
        }
        return parts.joined(separator: " · ")
    }

    static func humanBytes(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1f MB", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%d KB",   n / 1_000) }
        return "\(n) B"
    }
}

/// Status pill — used in the file Table and the inspector strip. Stock SF Symbols dot
/// + system semantic colours that follow light/dark/colour-blind preferences.
struct StatusPill: View {
    let state: ProcessingState
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(dotColor)
                .opacity(isProcessing && pulse ? 0.35 : 1.0)
                .animation(isProcessing ? .easeInOut(duration: 0.7).repeatForever() : .default, value: pulse)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(textColor)
        }
        .onAppear { if isProcessing { pulse = true } }
    }

    private var isProcessing: Bool {
        if case .processing = state { return true } else { return false }
    }

    private var label: String {
        switch state {
        case .raw: "Not removed"
        case .queued: "Queued"
        case .processing: "Removing…"
        case .done(let ms): ms > 0 ? "Done · \(ms) ms" : "Done"
        case .error: "Failed"
        }
    }

    private var dotColor: Color {
        switch state {
        case .raw: .secondary
        case .queued: .accentColor
        case .processing: .orange
        case .done: .green
        case .error: .red
        }
    }

    private var textColor: Color {
        switch state {
        case .raw: .secondary
        case .queued: .primary
        case .processing: .orange
        case .done: .green
        case .error: .red
        }
    }
}
