import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let remapper = KeyRemapper()
    private let defaults = UserDefaults.standard
    private var trustTimer: Timer?
    private var activationObserver: NSObjectProtocol?

    @Published var rules: [Rule] {
        didSet { save(rules, key: Keys.rules); remapper.rules = rules }
    }
    @Published var excludedApps: [ExcludedApp] {
        didSet { save(excludedApps, key: Keys.excluded); remapper.excludedBundleIDs = Set(excludedApps.map(\.bundleID)) }
    }
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled); updateTap() }
    }
    /// When false the menu bar icon is hidden; remapping keeps running. Reopening the app shows it again.
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }
    /// When true, "Quit" only hides the menu bar icon so shortcuts keep working.
    @Published var keepRunningAfterQuit: Bool {
        didSet { defaults.set(keepRunningAfterQuit, forKey: Keys.keepRunningAfterQuit) }
    }
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var tapFailed = false
    @Published private(set) var frontmostApp: NSRunningApplication?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private enum Keys {
        static let rules = "rules", excluded = "excludedApps", enabled = "isEnabled"
        static let showMenuBarIcon = "showMenuBarIcon", keepRunningAfterQuit = "keepRunningAfterQuit"
    }

    private init() {
        rules = Self.load([Rule].self, key: Keys.rules) ?? Defaults.rules
        excludedApps = Self.load([ExcludedApp].self, key: Keys.excluded) ?? Defaults.excludedApps
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        keepRunningAfterQuit = defaults.object(forKey: Keys.keepRunningAfterQuit) as? Bool ?? true

        remapper.rules = rules
        remapper.excludedBundleIDs = Set(excludedApps.map(\.bundleID))
        setFrontmost(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in self?.setFrontmost(app) }
        }

        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTrust() }
        }
        updateTap()
    }

    var isActive: Bool { isEnabled && isTrusted && remapper.isRunning }

    var isFrontmostExcluded: Bool {
        guard let id = frontmostApp?.bundleIdentifier else { return false }
        return excludedApps.contains { $0.bundleID == id }
    }

    // MARK: Rules

    func upsert(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    func delete(_ rule: Rule) { rules.removeAll { $0.id == rule.id } }

    func setRule(_ id: Rule.ID, enabled: Bool) {
        if let index = rules.firstIndex(where: { $0.id == id }) { rules[index].enabled = enabled }
    }

    func restoreDefaultRules() { rules = Defaults.rules }

    // MARK: Excluded apps

    func exclude(bundleID: String, name: String) {
        guard !excludedApps.contains(where: { $0.bundleID == bundleID }) else { return }
        excludedApps.append(ExcludedApp(bundleID: bundleID, name: name))
    }

    func removeExcluded(_ bundleID: String) { excludedApps.removeAll { $0.bundleID == bundleID } }

    func toggleFrontmostExclusion() {
        guard let app = frontmostApp, let id = app.bundleIdentifier else { return }
        if isFrontmostExcluded {
            removeExcluded(id)
        } else {
            exclude(bundleID: id, name: app.localizedName ?? id)
        }
    }

    func restoreDefaultExclusions() { excludedApps = Defaults.excludedApps }

    // MARK: Permissions & system

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        updateTap()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("KeyBridge: launch at login change failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
            updateTap()
        }
    }

    private func updateTap() {
        if isEnabled && isTrusted {
            tapFailed = !remapper.start()
        } else {
            remapper.stop()
            tapFailed = false
        }
        objectWillChange.send()
    }

    private func setFrontmost(_ app: NSRunningApplication?) {
        remapper.frontmostBundleID = app?.bundleIdentifier
        // Ignore our own windows so "Disable in <app>" keeps targeting the app the user was using.
        guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmostApp = app
    }

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
