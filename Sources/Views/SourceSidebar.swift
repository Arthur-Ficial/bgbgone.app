import SwiftUI

/// Finder-style sidebar. Lists "All Files" plus one row per dropped folder ("Source").
/// Selection filters the file table in the detail column.
struct SourceSidebar: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List(selection: $viewModel.sidebarSelection) {
            Section("Library") {
                NavigationLink(value: SidebarItem.all) {
                    Label("All Files", systemImage: "photo.on.rectangle")
                }
            }

            if !viewModel.batches.isEmpty {
                Section("Sources") {
                    ForEach(viewModel.batches) { batch in
                        NavigationLink(value: SidebarItem.batch(batch.id)) {
                            Label(batch.name, systemImage: "folder")
                                .badge(batch.imageCount)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
    }
}

/// Sidebar selection model. `nil` and `.all` both mean "show every file"; we use `.all`
/// as the canonical value because `List(selection:)` treats nil as "no row highlighted".
enum SidebarItem: Hashable {
    case all
    case batch(UUID)
}
