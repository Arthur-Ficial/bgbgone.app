import SwiftUI

/// Dual preview pinned to the top of the middle column. Two equal panes
/// side by side. The CUTOUT pane shows the standard gray/white checker
/// behind the cutout image (sized to the IMAGE'S frame so the checker
/// matches the cutout's aspect ratio, not the full pane).
///
/// Both panes share a single zoom + pan state — pinching/dragging on
/// EITHER pane drives the other in lock-step. Stock SwiftUI gestures:
/// `MagnifyGesture` + `DragGesture`, double-click to reset, and a
/// floating `+ / − / ⟲` control for keyboard / mouse-only users.
struct BigDualPreview: View {
    let viewModel: AppViewModel

    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero

    private static let minZoom: CGFloat = 1
    private static let maxZoom: CGFloat = 6
    private static let zoomStep: CGFloat = 1.4

    var body: some View {
        HStack(spacing: 14) {
            previewPane(label: "ORIGINAL", url: originalURL, isCutout: false)
            previewPane(label: "CUTOUT", url: cutoutURL, isCutout: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottomTrailing) {
            zoomControls
                .padding(.trailing, 22)
                .padding(.bottom, 18)
        }
        .onChange(of: viewModel.selectedId) { _, _ in resetZoom() }
    }

    private var selectedFile: ImageFile? { viewModel.selectedFile }

    private var originalURL: URL? { selectedFile?.url }

    private var cutoutURL: URL? {
        guard let file = selectedFile, file.cutoutExists else { return nil }
        return file.cutoutURL(in: file.config)
    }

    /// True when the CUTOUT image's backdrop should be the alpha-channel
    /// checker (only when the selected file's background is `.transparent`).
    private var cutoutNeedsChecker: Bool {
        guard let file = selectedFile else { return false }
        if case .transparent = file.config.background { return true }
        return false
    }

    @ViewBuilder
    private func previewPane(label: String, url: URL?, isCutout: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05))
                )
            if let url {
                CachedThumbnailView(url: url, showChecker: isCutout && cutoutNeedsChecker)
                    .scaleEffect(zoom, anchor: .center)
                    .offset(pan)
                    .padding(10)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            cornerLabel(label)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .gesture(zoomAndPanGesture)
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.18)) { resetZoom() }
        }
    }

    /// Floating `+ / − / ⟲` control. For mouse-only users with no
    /// pinch gesture. Stock `Button` + SF Symbols inside a thin material
    /// `Capsule`.
    @ViewBuilder private var zoomControls: some View {
        HStack(spacing: 0) {
            Button(action: zoomOut) { Image(systemName: "minus.magnifyingglass") }
                .disabled(zoom <= Self.minZoom)
                .help("Zoom out")
            Divider().frame(height: 16)
            Button(action: zoomIn) { Image(systemName: "plus.magnifyingglass") }
                .disabled(zoom >= Self.maxZoom)
                .help("Zoom in")
            Divider().frame(height: 16)
            Button(action: { withAnimation(.easeOut(duration: 0.18)) { resetZoom() } }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(zoom == Self.minZoom && pan == .zero)
            .help("Reset zoom")
        }
        .buttonStyle(.plain)
        .imageScale(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator))
    }

    /// `SimultaneousGesture` so trackpad pinch (`MagnifyGesture`) and
    /// drag-pan coexist; either updates the shared zoom/pan that BOTH
    /// panes observe.
    private var zoomAndPanGesture: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let next = committedZoom * value.magnification
                    zoom = min(Self.maxZoom, max(Self.minZoom, next))
                }
                .onEnded { _ in
                    committedZoom = zoom
                    if zoom <= Self.minZoom { resetZoom() }
                },
            DragGesture()
                .onChanged { value in
                    guard zoom > Self.minZoom else { return }
                    pan = CGSize(
                        width: committedPan.width + value.translation.width,
                        height: committedPan.height + value.translation.height
                    )
                }
                .onEnded { _ in committedPan = pan }
        )
    }

    private func zoomIn() {
        withAnimation(.easeOut(duration: 0.18)) {
            zoom = min(Self.maxZoom, zoom * Self.zoomStep)
            committedZoom = zoom
        }
    }

    private func zoomOut() {
        withAnimation(.easeOut(duration: 0.18)) {
            zoom = max(Self.minZoom, zoom / Self.zoomStep)
            committedZoom = zoom
            if zoom <= Self.minZoom { resetZoom() }
        }
    }

    private func resetZoom() {
        zoom = Self.minZoom
        committedZoom = Self.minZoom
        pan = .zero
        committedPan = .zero
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
