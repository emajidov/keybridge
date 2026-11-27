import AppKit
import SwiftUI

@main
struct KeyBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(state)
        } label: {
            Image(systemName: state.isActive ? "keyboard.fill" : "keyboard")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        let firstLaunchKey = "hasLaunchedBefore"
        if !AppState.shared.isTrusted || !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @MainActor
    func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: MainView().environmentObject(AppState.shared))
            let window = NSWindow(contentViewController: hosting)
            window.title = "KeyBridge"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("KeyBridgeMain")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct MenuContent: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Toggle("Remapping Enabled", isOn: $state.isEnabled)
        if !state.isTrusted {
            Button("Grant Accessibility Permission…") {
                state.requestAccessibility()
                AppDelegate.shared?.showMainWindow()
            }
        }
        if let app = state.frontmostApp, let name = app.localizedName {
            Divider()
            Button(state.isFrontmostExcluded ? "Enable in \(name)" : "Disable in \(name)") {
                state.toggleFrontmostExclusion()
            }
        }
        Divider()
        Button("Settings…") { AppDelegate.shared?.showMainWindow() }
            .keyboardShortcut(",")
        Button("Quit KeyBridge") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
