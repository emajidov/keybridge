import AppKit
import SwiftUI

@main
struct KeyBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        // MenuBarExtra writes isInserted back on every update; ignore unchanged values or the
        // @Published write re-triggers the update in an endless loop.
        MenuBarExtra(isInserted: Binding(get: { state.showMenuBarIcon },
                                         set: { if state.showMenuBarIcon != $0 { state.showMenuBarIcon = $0 } })) {
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
        AppState.shared.showMenuBarIcon = true
        showMainWindow()
        return true
    }

    /// Hides the menu bar icon and settings window while remapping keeps running.
    @MainActor
    func moveToBackground() {
        AppState.shared.showMenuBarIcon = false
        window?.close()
        let suppressKey = "suppressBackgroundAlert"
        guard !UserDefaults.standard.bool(forKey: suppressKey) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "KeyBridge is still running in the background"
        alert.informativeText = "Your shortcuts keep working. To show the menu bar icon or change settings, open KeyBridge again from Applications or Spotlight. To stop KeyBridge completely, use Quit Completely in Settings → General."
        alert.showsSuppressionButton = true
        alert.runModal()
        if alert.suppressionButton?.state == .on { UserDefaults.standard.set(true, forKey: suppressKey) }
    }

    private var quitCompletelyRequested = false

    @MainActor
    func quitCompletely() {
        quitCompletelyRequested = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Logout, restart and scripted quits arrive as an Apple Event and must always succeed.
        let isSystemQuit = NSAppleEventManager.shared().currentAppleEvent != nil
        guard AppState.shared.keepRunningAfterQuit, !quitCompletelyRequested, !isSystemQuit else { return .terminateNow }
        DispatchQueue.main.async { self.moveToBackground() }
        return .terminateCancel
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
        Button("Hide Menu Bar Icon") { AppDelegate.shared?.moveToBackground() }
        Button("Settings…") { AppDelegate.shared?.showMainWindow() }
            .keyboardShortcut(",")
        Button("Quit KeyBridge") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
