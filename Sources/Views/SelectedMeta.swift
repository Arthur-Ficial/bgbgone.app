import SwiftUI

/// Strip below DualPreview: filename + dims/bytes/ms + status pill.
struct SelectedMeta: View {
    let file: ImageFile?

    var body: some View {
        if let file {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(file.name)
                    .font(DesignFont.displayName)
                    .foregroundStyle(DesignColor.fg)
                    .tracking(-0.17)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(metaLine(for: file))
                    .font(DesignFont.mono)
                    .foregroundStyle(DesignColor.fgFaint)

                Spacer()

                StatusPill(state: file.state)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
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

struct StatusPill: View {
    let state: ProcessingState
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .opacity(state.pillClass == "processing" && pulse ? 0.35 : 1)
                .animation(state.pillClass == "processing"
                           ? .easeInOut(duration: 0.7).repeatForever() : .default,
                           value: pulse)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textColor)
        }
        .onAppear { if state.pillClass == "processing" { pulse = true } }
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
        case .raw: DesignColor.fgGhost
        case .queued: DesignColor.accent
        case .processing: DesignColor.amber
        case .done: DesignColor.green
        case .error: DesignColor.red
        }
    }

    private var textColor: Color {
        switch state {
        case .raw: DesignColor.fgMute
        case .queued: DesignColor.accent
        case .processing: DesignColor.amber
        case .done: DesignColor.green
        case .error: DesignColor.red
        }
    }
}
