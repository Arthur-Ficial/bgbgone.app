import SwiftUI
import AppKit

@main
struct BgBgOneApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("bgbgone") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1080, idealWidth: 1080, minHeight: 760, idealHeight: 760)
                .background(DesignColor.outerGradient.ignoresSafeArea())
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}

struct ContentView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isDropTargeted = false
    @State private var currentDragHint: DragHint = .empty
    @State private var isDebugOpen: Bool = ProcessInfo.processInfo.arguments.contains("--debug")

    var body: some View {
        ZStack {
            switch viewModel.bootState {
            case .starting:
                ProgressView().controlSize(.small)
            case .missingBinary(let searched):
                MissingBinaryView(searched: searched, onRetry: { /* reload via app restart for v0.1 */ })
            case .ready:
                mainWindow
            }
        }
        .background(DesignColor.bg)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.window))
        .overlay(
            RoundedRectangle(cornerRadius: DesignRadius.window)
                .strokeBorder(DesignColor.border)
        )
        .shadow(color: .black.opacity(0.34), radius: 28, x: 0, y: 30)
        .padding(20)
        .overlay(alignment: .bottomTrailing) {
            if isDebugOpen {
                DebugOverlay(viewModel: viewModel, log: DebugLog.shared) {
                    isDebugOpen = false
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .background {
            // Background keyboard handler: cmd-` toggles the debug overlay.
            Button("") { isDebugOpen.toggle() }
                .keyboardShortcut("`", modifiers: .command)
                .opacity(0)
        }
        .animation(.easeOut(duration: 0.16), value: isDebugOpen)
    }

    @ViewBuilder private var mainWindow: some View {
        VStack(spacing: 0) {
            WindowChrome(
                pendingCount: viewModel.pendingCount,
                canProcess: viewModel.pendingCount > 0,
                onAddFiles: addFiles,
                onProcessAll: { Task { await viewModel.processAll() } }
            )

            DualPreview(
                selected: viewModel.files.first(where: { $0.id == viewModel.selectedId }),
                isEmpty: viewModel.files.isEmpty,
                background: viewModel.config.background,
                onPickFolder: pickFolder,
                onPickFiles: addFiles
            )

            SelectedMeta(file: viewModel.files.first(where: { $0.id == viewModel.selectedId }))

            ConfigPanel(viewModel: viewModel)

            FileListView(viewModel: viewModel) { viewModel.dismissSummary() }

            StatusBar(viewModel: viewModel)
        }
        .dropDestination(for: URL.self) { urls, _ in
            Task { await viewModel.handleDrop(urls: urls) }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
            if targeted {
                viewModel.handleDragEnter(hint: DragHint(folderCount: 0, imageCount: 1, otherCount: 0, folderName: ""))
            } else {
                viewModel.handleDragLeave()
            }
        }
        .overlay {
            if case .drag(let hint) = viewModel.dropMachine.phase {
                DropVeil(hint: hint)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if case .ingest(let state) = viewModel.dropMachine.phase {
                IngestOverlay(state: state, onCancel: { viewModel.dismissSummary() })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: phaseIndex)
    }

    /// Pluck a stable index off the drop phase so SwiftUI animates on transitions.
    private var phaseIndex: Int {
        switch viewModel.dropMachine.phase {
        case .idle: 0
        case .drag: 1
        case .ingest: 2
        case .summary: 3
        }
    }

    // MARK: - File pickers + drop

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        Task { await viewModel.handleDrop(urls: panel.urls) }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await viewModel.handleDrop(urls: [url]) }
    }

}
