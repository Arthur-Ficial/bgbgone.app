import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct BgBgOneApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("bgbgone") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1100, idealWidth: 1180, minHeight: 720, idealHeight: 780)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isDropTargeted = false
    @State private var isInspectorPresented: Bool = true
    @State private var isDebugOpen: Bool = ProcessInfo.processInfo.arguments.contains("--debug")
    @State private var demoAttributionShown: Bool = false
    @State private var demoManifest: DemoManifest? = nil

    var body: some View {
        Group {
            switch viewModel.bootState {
            case .starting:
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missingBinary(let searched):
                MissingBinaryView(searched: searched, onRetry: { /* reload via app restart */ })
            case .ready:
                mainWindow
            }
        }
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
            Button("") { isDebugOpen.toggle() }
                .keyboardShortcut("`", modifiers: .command)
                .opacity(0)
        }
        .animation(.easeOut(duration: 0.16), value: isDebugOpen)
    }

    @ViewBuilder private var mainWindow: some View {
        NavigationSplitView {
            SourceSidebar(viewModel: viewModel)
        } detail: {
            FileListView(
                viewModel: viewModel,
                onTryDemo: requestDemo,
                onDismissSummary: { viewModel.dismissSummary() }
            )
            .navigationTitle("bgbgone")
            .navigationSubtitle(subtitle)
            .sheet(isPresented: $demoAttributionShown) {
                if let manifest = demoManifest {
                    DemoAttributionView(
                        manifest: manifest,
                        onConfirm: {
                            demoAttributionShown = false
                            startDemo()
                        },
                        onCancel: { demoAttributionShown = false }
                    )
                } else {
                    VStack {
                        Text("Could not load demo-manifest.json")
                            .font(.headline)
                        Button("OK") { demoAttributionShown = false }
                    }
                    .padding(40)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatusBar(viewModel: viewModel)
            }
            .inspector(isPresented: $isInspectorPresented) {
                InspectorPane(viewModel: viewModel)
                    .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await viewModel.processAll() } }) {
                        if viewModel.pendingCount > 0 {
                            Label("Remove background from \(viewModel.pendingCount)", systemImage: "wand.and.stars")
                        } else {
                            Label("All done", systemImage: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.pendingCount == 0)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addFiles) {
                        Label("Add files…", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isInspectorPresented.toggle() }) {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                    .help("Show / hide inspector")
                }
            }
        }
    }

    private var subtitle: String {
        let n = viewModel.files.count
        if n == 0 { return "Drop a folder to begin" }
        return "\(n) image\(n == 1 ? "" : "s")"
    }

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

    private func requestDemo() {
        demoManifest = DemoManifest.loadFromBundle()
        demoAttributionShown = true
    }

    private func startDemo() {
        guard let script = DemoManifest.scriptURL(),
              let manifest = DemoManifest.manifestURL() else {
            return
        }
        Task { await viewModel.startDemo(scriptURL: script, manifestURL: manifest) }
    }
}

/// Right-side inspector: preview pair on top, selected-file metadata strip, config form.
private struct InspectorPane: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let selected = viewModel.files.first(where: { $0.id == viewModel.selectedId }) {
                    DualPreview(
                        selected: selected,
                        isEmpty: viewModel.files.isEmpty,
                        config: viewModel.config,
                        onPickFolder: {},
                        onPickFiles: {}
                    )
                    SelectedMeta(file: selected)
                    Divider()
                } else if viewModel.files.isEmpty {
                    InspectorEmpty()
                        .frame(minHeight: 280)
                } else {
                    InspectorPickHint()
                        .frame(minHeight: 280)
                }

                ConfigPanel(viewModel: viewModel)
            }
        }
    }
}

private struct InspectorEmpty: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No image selected")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Drop images on the file list to begin.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InspectorPickHint: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Pick a file in the list")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
