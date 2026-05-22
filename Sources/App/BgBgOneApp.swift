import SwiftUI

@main
struct BgBgOneApp: App {
    var body: some Scene {
        WindowGroup("bgbgone") {
            ContentView()
                .frame(minWidth: 1080, minHeight: 760)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}

struct ContentView: View {
    var body: some View {
        Text("bgbgone — scaffolding")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
    }
}
