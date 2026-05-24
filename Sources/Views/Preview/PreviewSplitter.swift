import SwiftUI
import AppKit

/// T12: 4px horizontal splitter handle between the big dual preview (above) and the
/// file list (below). Drag adjusts `height` between 180 and 340. NSCursor.resizeUpDown
/// shows on hover via an `NSViewRepresentable` cursor zone.
struct PreviewSplitter: View {
    @Binding var height: Double

    var body: some View {
        Rectangle()
            .fill(Color.separator)
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 6)
                    .contentShape(Rectangle())
                    .background(CursorZone())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let next = height + Double(value.translation.height)
                                height = max(180, min(340, next))
                            }
                    )
            )
    }
}

private struct CursorZone: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ view: CursorView, context: Context) {}

    final class CursorView: NSView {
        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }
}

private extension Color {
    static var separator: Color { Color(nsColor: .separatorColor) }
}
