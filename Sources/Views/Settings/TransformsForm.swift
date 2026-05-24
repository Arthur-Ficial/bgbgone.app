import SwiftUI

/// T14 — first-class controls for the foreground transforms (scale / translate /
/// rotate / flip). These replace the deleted CLI flags `--scale` and `--position`.
struct TransformsForm: View {
    @Bindable var viewModel: AppViewModel
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup("Foreground transforms", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                scaleRow
                translateRow
                rotateRow
                flipRow
            }
            .padding(.vertical, 6)
        }
        .help("Scale, position, rotate, flip the subject in the output frame.")
    }

    @ViewBuilder
    private var scaleRow: some View {
        let isOn = Binding(
            get: { viewModel.config.fgScale != nil },
            set: { viewModel.config.fgScale = $0 ? (viewModel.config.fgScale ?? 1.0) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Scale", isOn: isOn)
            if let v = viewModel.config.fgScale {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { viewModel.config.fgScale = $0 }
                    ), in: 0.1...3.0)
                    Text(String(format: "%.2f×", v)).monospacedDigit().frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var translateRow: some View {
        let isOn = Binding(
            get: { viewModel.config.fgTranslateX != nil },
            set: { on in
                viewModel.config.fgTranslateX = on ? (viewModel.config.fgTranslateX ?? 0) : nil
                viewModel.config.fgTranslateY = on ? (viewModel.config.fgTranslateY ?? 0) : nil
            }
        )
        Toggle("Translate", isOn: isOn)
        if let x = viewModel.config.fgTranslateX, let y = viewModel.config.fgTranslateY {
            HStack {
                Stepper("X: \(x) px", value: Binding(
                    get: { x },
                    set: { viewModel.config.fgTranslateX = $0 }
                ), in: -2000...2000)
                Stepper("Y: \(y) px", value: Binding(
                    get: { y },
                    set: { viewModel.config.fgTranslateY = $0 }
                ), in: -2000...2000)
            }
        }
    }

    @ViewBuilder
    private var rotateRow: some View {
        let isOn = Binding(
            get: { viewModel.config.fgRotate != nil },
            set: { viewModel.config.fgRotate = $0 ? (viewModel.config.fgRotate ?? 0) : nil }
        )
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Rotate", isOn: isOn)
            if let v = viewModel.config.fgRotate {
                HStack {
                    Slider(value: Binding(
                        get: { v },
                        set: { viewModel.config.fgRotate = $0 }
                    ), in: -180...180)
                    Text("\(Int(v))°").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var flipRow: some View {
        let isOn = Binding(
            get: { viewModel.config.fgFlip != nil },
            set: { viewModel.config.fgFlip = $0 ? (viewModel.config.fgFlip ?? "horizontal") : nil }
        )
        Toggle("Flip", isOn: isOn)
        if let v = viewModel.config.fgFlip {
            Picker("Direction", selection: Binding(
                get: { v },
                set: { viewModel.config.fgFlip = $0 }
            )) {
                Text("Horizontal").tag("horizontal")
                Text("Vertical").tag("vertical")
            }
            .pickerStyle(.segmented)
        }
    }
}
