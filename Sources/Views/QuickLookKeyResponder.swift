import SwiftUI
import AppKit
import QuickLookUI

/// Hidden NSView wrapper that handles Space, Return, and Delete key events for the
/// file list. Space → system Quick Look (real `QLPreviewPanel.shared()`); Return →
/// open in default app via `NSWorkspace.shared.open`; Delete → remove from queue (the
/// SwiftUI side handles the ≥10 confirm sheet before calling).
struct QuickLookKeyResponder: NSViewRepresentable {
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> KeyResponderView {
        let view = KeyResponderView()
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ view: KeyResponderView, context: Context) {
        view.onSpace = onSpace
        view.onReturn = onReturn
        view.onDelete = onDelete
    }

    final class KeyResponderView: NSView {
        var onSpace: () -> Void = {}
        var onReturn: () -> Void = {}
        var onDelete: () -> Void = {}

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49: onSpace()       // Space
            case 36, 76: onReturn()  // Return, numpad Enter
            case 51, 117: onDelete() // Delete (Backspace), Forward Delete
            default: super.keyDown(with: event)
            }
        }

        override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel) -> Bool { true }

        override func beginPreviewPanelControl(_ panel: QLPreviewPanel) {
            panel.delegate = QuickLookController.shared
            panel.dataSource = QuickLookController.shared
        }

        override func endPreviewPanelControl(_ panel: QLPreviewPanel) {
            panel.delegate = nil
            panel.dataSource = nil
        }
    }
}

/// Singleton holding the URL list Quick Look reads. Set the list, then call
/// `present()` to make the system panel front. `QLPreviewPanel.shared()` is the real
/// Finder panel — no custom UI.
@MainActor
final class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    static let shared = QuickLookController()
    private var urls: [URL] = []

    func present(urls: [URL]) {
        guard !urls.isEmpty else { return }
        self.urls = urls
        let panel = QLPreviewPanel.shared()
        if panel?.isVisible == true {
            panel?.reloadData()
        } else {
            panel?.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
