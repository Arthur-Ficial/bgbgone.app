import AppKit

/// One-shot pass that nukes the macOS-default menu items SwiftUI's
/// `CommandGroup(replacing:)` can't reach: empty top-level menus (Format,
/// Help), the window-tabbing items in View / Window, and any
/// AppKit-injected text helpers we don't need (Writing Tools, AutoFill,
/// Dictation, etc.).
///
/// Idempotent. The `NSApplicationDelegate` hook fires it once at finish-
/// launch AND once more on the next runloop tick to catch late injects.
final class MenuBarPruner: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window tabbing entirely — kills "Show Tab Bar",
        // "Move Tab to New Window", "Merge All Windows", etc.
        NSWindow.allowsAutomaticWindowTabbing = false
        // SwiftUI's .commands menus + AppKit's text-helper injects land
        // on the main runloop in stages. Prune at a few well-spaced
        // ticks so we catch every late insert; the operation is
        // idempotent and cheap.
        for delay in [0.0, 0.05, 0.25, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Self.prune() }
        }
        // Also re-prune whenever any menu is about to open — covers any
        // future late insert we haven't seen yet.
        for top in NSApp.mainMenu?.items ?? [] {
            top.submenu?.delegate = self
        }
    }

    func menuWillOpen(_ menu: NSMenu) { Self.prune() }

    @MainActor
    static func prune() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for top in Array(mainMenu.items) {
            top.submenu.map(pruneSubmenu)
            let isEmpty = (top.submenu?.items.filter { !$0.isSeparatorItem }.isEmpty ?? true)
            if isEmpty { mainMenu.removeItem(top) }
        }
    }

    private static let noiseItemTitles: Set<String> = [
        // View / Window tab-bar noise
        "Show Tab Bar", "Hide Tab Bar",
        "Show All Tabs", "Hide All Tabs",
        "Merge All Windows",
        "Move Tab to New Window",
        "Show Previous Tab", "Show Next Tab",
        "Remove Window from Set",
        // Window-menu noise we don't need
        "Move & Resize", "Full Screen Tile", "Fill", "Center",
        "Minimize All", "Zoom All",
        // Edit menu AppKit text-helper injects
        "Writing Tools", "AutoFill", "Start Dictation",
        "Emoji & Symbols",
    ]

    /// Substrings that mark an item as noise even when the exact title
    /// drifts (Apple sometimes renames "Start Dictation…" → "Dictation",
    /// adds ellipses, localises, etc.).
    private static let noiseSubstrings: [String] = [
        "Dictation", "Writing Tools", "AutoFill",
        "Emoji & Symbols", "Substitutions", "Transformations",
        "Speech", "Special Characters",
    ]

    @MainActor
    private static func pruneSubmenu(_ submenu: NSMenu) {
        for item in Array(submenu.items) {
            let drop = noiseItemTitles.contains(item.title)
                || noiseSubstrings.contains { item.title.contains($0) }
            if drop {
                submenu.removeItem(item)
                continue
            }
            // Recurse into nested submenus
            item.submenu.map(pruneSubmenu)
        }
        collapseSeparators(submenu)
    }

    @MainActor
    private static func collapseSeparators(_ menu: NSMenu) {
        while let first = menu.items.first, first.isSeparatorItem {
            menu.removeItem(first)
        }
        while let last = menu.items.last, last.isSeparatorItem {
            menu.removeItem(last)
        }
        var i = 1
        while i < menu.items.count {
            if menu.items[i].isSeparatorItem && menu.items[i - 1].isSeparatorItem {
                menu.removeItem(at: i)
            } else {
                i += 1
            }
        }
    }
}
