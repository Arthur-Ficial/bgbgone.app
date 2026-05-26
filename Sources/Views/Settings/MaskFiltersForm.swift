import SwiftUI

/// T14 — first-class controls for the high-value mask filters. Each is gated by an
/// activator `Toggle`; when on, the corresponding `Config` field carries a value, when
/// off it's `nil` and no recipe is emitted.
struct MaskFiltersForm: View {
    @Binding var config: Config
    @State private var isExpanded: Bool = false

    var body: some View {
        ClickRowDisclosure(title: "Mask refinement", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                featherRow
                thresholdRow
                expandRow
                contractRow
            }
            .padding(.vertical, 6)
        }
        .help("Edge softening, threshold, dilation/erosion — applied to the mask.")
    }

    @ViewBuilder
    private var featherRow: some View {
        let isOn = Binding(
            get: { config.maskFeather != nil },
            set: { config.maskFeather = $0 ? (config.maskFeather ?? 8) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Soften edges (feather)", isOn: isOn)
            if let v = config.maskFeather {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { config.maskFeather = $0 }
                    ), in: 0...30)
                    Text("\(Int(v)) px").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var thresholdRow: some View {
        let isOn = Binding(
            get: { config.maskThreshold != nil },
            set: { config.maskThreshold = $0 ? (config.maskThreshold ?? 0.5) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Threshold (cleanup fringe)", isOn: isOn)
            if let v = config.maskThreshold {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { config.maskThreshold = $0 }
                    ), in: 0...1)
                    Text(String(format: "%.2f", v)).monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var expandRow: some View {
        let isOn = Binding(
            get: { config.maskExpand != nil },
            set: { config.maskExpand = $0 ? (config.maskExpand ?? 2) : nil }
        )
        Toggle("Expand mask", isOn: isOn)
        if let v = config.maskExpand {
            Stepper("Expand: \(v) px", value: Binding(
                get: { v },
                set: { config.maskExpand = $0 }
            ), in: 0...20)
        }
    }

    @ViewBuilder
    private var contractRow: some View {
        let isOn = Binding(
            get: { config.maskContract != nil },
            set: { config.maskContract = $0 ? (config.maskContract ?? 2) : nil }
        )
        Toggle("Contract mask", isOn: isOn)
        if let v = config.maskContract {
            Stepper("Contract: \(v) px", value: Binding(
                get: { v },
                set: { config.maskContract = $0 }
            ), in: 0...20)
        }
    }
}
