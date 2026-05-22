import SwiftUI

/// Custom 44px title bar matching `design/project/styles.css` `.titlebar`.
///
/// Traffic lights on the left, centred "bgbgone" wordmark, action buttons on the right.
/// The `Remove background from N` button reads "All done" when the queue is empty
/// after a run.
struct WindowChrome: View {
    let pendingCount: Int
    let canProcess: Bool
    let onAddFiles: () -> Void
    let onProcessAll: () -> Void

    var body: some View {
        ZStack {
            // Centred brand wordmark
            Text("bgbgone")
                .font(DesignFont.display)
                .foregroundStyle(DesignColor.fg)
                .tracking(-0.06)

            HStack(spacing: 0) {
                TrafficLights()
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onAddFiles) {
                        Text("Add files…")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button(action: onProcessAll) {
                        primaryButtonContent
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canProcess)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignColor.border)
                .frame(height: 1)
        }
    }

    @ViewBuilder private var primaryButtonContent: some View {
        if pendingCount > 0 {
            HStack(spacing: 4) {
                Text("Remove background from")
                Text("\(pendingCount)").bold().monospacedDigit()
            }
        } else {
            Text("All done")
        }
    }
}

private struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(DesignColor.trafficRed).frame(width: 12, height: 12)
            Circle().fill(DesignColor.trafficYellow).frame(width: 12, height: 12)
            Circle().fill(DesignColor.trafficGreen).frame(width: 12, height: 12)
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 11)
            .frame(height: 26)
            .foregroundStyle(DesignColor.fg)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? DesignColor.bgSoft : .clear)
            )
            .contentShape(Rectangle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 13)
            .frame(height: 26)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(isEnabled ? .white : DesignColor.fgFaint)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled
                          ? (configuration.isPressed ? DesignColor.accentPress : DesignColor.accent)
                          : Color(red: 220/255, green: 222/255, blue: 226/255))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0), lineWidth: 1)
            )
    }
}
