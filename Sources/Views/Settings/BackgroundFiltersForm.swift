import SwiftUI

/// T14 — first-class controls for background-layer filters (grayscale / blur /
/// desaturate). Most popular use is `bg:blur=N` for the classic portrait bokeh effect.
struct BackgroundFiltersForm: View {
    @Binding var config: Config
    @State private var isExpanded: Bool = false

    var body: some View {
        ClickRowDisclosure(title: "Background filters", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                grayscaleRow
                blurRow
                desaturateRow
            }
            .padding(.vertical, 6)
        }
        .help("Recolor or blur the background layer behind the cutout subject.")
    }

    private var grayscaleRow: some View {
        Toggle("Grayscale background", isOn: $config.bgGrayscale)
    }

    @ViewBuilder
    private var blurRow: some View {
        let isOn = Binding(
            get: { config.bgBlur != nil },
            set: { config.bgBlur = $0 ? (config.bgBlur ?? 15) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Blur background", isOn: isOn)
            if let v = config.bgBlur {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { config.bgBlur = $0 }
                    ), in: 0...60)
                    Text("\(Int(v)) px").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var desaturateRow: some View {
        let isOn = Binding(
            get: { config.bgDesaturate != nil },
            set: { config.bgDesaturate = $0 ? (config.bgDesaturate ?? 0.5) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Desaturate background", isOn: isOn)
            if let v = config.bgDesaturate {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { config.bgDesaturate = $0 }
                    ), in: 0...1)
                    Text(String(format: "%.2f", v)).monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
}
