import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !state.isTrusted { PermissionBanner() }
            TabView {
                ShortcutsView().tabItem { Label("Shortcuts", systemImage: "keyboard") }
                ExcludedAppsView().tabItem { Label("Excluded Apps", systemImage: "nosign") }
                GeneralView().tabItem { Label("General", systemImage: "gearshape") }
            }
            .padding()
        }
        .frame(minWidth: 680, minHeight: 480)
    }
}

struct PermissionBanner: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission needed").bold()
                Text("KeyBridge needs Accessibility access to remap shortcuts. Enable KeyBridge in System Settings → Privacy & Security → Accessibility.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant Access…") {
                state.requestAccessibility()
                state.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12))
    }
}

// MARK: - Shortcuts

struct ShortcutsView: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: Rule?
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Remapping enabled", isOn: $state.isEnabled).toggleStyle(.switch)
                Spacer()
                StatusBadge()
            }
            List {
                ForEach(state.rules) { rule in
                    RuleRow(rule: rule, onEdit: { editing = rule })
                }
                .onMove { state.rules.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            HStack {
                Button {
                    editing = Rule(name: "", from: KeyCombo(keyCode: KeyCode.c, modifiers: .control),
                                   to: KeyCombo(keyCode: KeyCode.c, modifiers: .command))
                } label: { Label("Add Shortcut", systemImage: "plus") }
                Button("Restore Defaults…") { confirmReset = true }
                Spacer()
                Text("⌃ Control   ⌥ Option   ⇧ Shift   ⌘ Command")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editing) { rule in
            RuleEditor(rule: rule) { state.upsert($0) }
        }
        .confirmationDialog("Replace all shortcuts with the defaults?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) { state.restoreDefaultRules() }
        }
    }
}

struct StatusBadge: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let (text, color): (String, Color) = {
            if !state.isTrusted { return ("Needs permission", .orange) }
            if state.tapFailed { return ("Could not start", .red) }
            return state.isActive ? ("Active", .green) : ("Off", .secondary)
        }()
        return Label(text, systemImage: "circle.fill")
            .font(.caption)
            .foregroundStyle(color)
    }
}

struct RuleRow: View {
    @EnvironmentObject private var state: AppState
    let rule: Rule
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { rule.enabled }, set: { state.setRule(rule.id, enabled: $0) }))
                .labelsHidden()
            Text(rule.name.isEmpty ? "Untitled" : rule.name)
                .frame(width: 220, alignment: .leading)
                .foregroundStyle(rule.enabled ? .primary : .secondary)
            KeyCap(text: rule.from.displayString)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            KeyCap(text: rule.to.displayString)
            if rule.includeShift {
                Text("+ ⇧ too").font(.caption).foregroundStyle(.secondary)
                    .help("Also applies when Shift is held, e.g. to select text")
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("Edit")
            Button { state.delete(rule) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("Delete")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .rounded).weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: 56)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.35)))
    }
}

struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var rule: Rule
    let onSave: (Rule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                TextField("Name", text: $rule.name, prompt: Text("e.g. Copy"))
                LabeledContent("When I press") { ShortcutRecorder(combo: $rule.from) }
                LabeledContent("Send instead") { ShortcutRecorder(combo: $rule.to) }
                Toggle("Also apply when Shift is held (e.g. for selecting text)", isOn: $rule.includeShift)
                    .disabled(rule.from.modifiers.contains(.shift))
            }
            .formStyle(.grouped)
            Text("Click a shortcut field, then press the keys. Shortcuts reserved by macOS (like ⌃← for Spaces) may need to be turned off in System Settings → Keyboard → Keyboard Shortcuts first.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(rule.from == rule.to)
            }
            .padding(20)
        }
        .frame(width: 480)
    }
}

struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button { isRecording ? stop() : start() } label: {
            Text(isRecording ? "Press shortcut…" : combo.displayString)
                .frame(minWidth: 140)
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        AppState.shared.remapper.isPaused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            combo = KeyCombo(keyCode: event.keyCode, modifiers: Modifiers(nsFlags: event.modifierFlags))
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        AppState.shared.remapper.isPaused = false
    }
}

// MARK: - Excluded apps

struct ExcludedAppsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts are not remapped in these apps. Keep terminals here so ⌃C still stops a running command, and virtual machines / remote desktops so Windows gets the real keys.")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach(state.excludedApps) { app in
                    HStack(spacing: 10) {
                        AppIcon(bundleID: app.bundleID)
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { state.removeExcluded(app.bundleID) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).help("Remove")
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            HStack {
                Menu {
                    ForEach(runningApps, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                            if let id = app.bundleIdentifier { state.exclude(bundleID: id, name: app.localizedName ?? id) }
                        }
                    }
                } label: { Label("Add Running App", systemImage: "plus") }
                .fixedSize()
                Button("Choose App…", action: chooseApp)
                Spacer()
                Button("Restore Defaults") { state.restoreDefaultExclusions() }
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            state.exclude(bundleID: id, name: name)
        }
    }
}

struct AppIcon: View {
    let bundleID: String

    var body: some View {
        let icon: NSImage = {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }()
        return Image(nsImage: icon).resizable().frame(width: 24, height: 24)
    }
}

// MARK: - General

struct GeneralView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle("Launch KeyBridge at login",
                       isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                LabeledContent("Accessibility permission") {
                    if state.isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings…") {
                            state.requestAccessibility()
                            state.openAccessibilitySettings()
                        }
                    }
                }
            }
            Section("How it works") {
                Text("KeyBridge lets you keep your Windows / Linux muscle memory on a Mac. When you press a shortcut like ⌃C (Ctrl+C), it is sent to the app as ⌘C (Cmd+C). Your ⌘ shortcuts keep working as usual.")
                Text("Tip: if you'd rather physically swap the Control and Command keys everywhere, macOS can do that natively in System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys.")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Quit KeyBridge") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
    }
}
