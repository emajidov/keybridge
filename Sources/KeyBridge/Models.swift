import AppKit
import Carbon.HIToolbox
import CoreGraphics

struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let control = Modifiers(rawValue: 1 << 0)
    static let option = Modifiers(rawValue: 1 << 1)
    static let shift = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    init(rawValue: Int) { self.rawValue = rawValue }

    init(cgFlags flags: CGEventFlags) {
        self.init(rawValue: 0)
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    init(nsFlags flags: NSEvent.ModifierFlags) {
        self.init(rawValue: 0)
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }

    /// Device-independent masks plus the matching left-side device bits, as real keyboards report them.
    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert([.maskControl, CGEventFlags(rawValue: 0x01)]) }
        if contains(.shift) { flags.insert([.maskShift, CGEventFlags(rawValue: 0x02)]) }
        if contains(.command) { flags.insert([.maskCommand, CGEventFlags(rawValue: 0x08)]) }
        if contains(.option) { flags.insert([.maskAlternate, CGEventFlags(rawValue: 0x20)]) }
        return flags
    }

    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

struct KeyCombo: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: Modifiers

    var displayString: String { modifiers.symbols + KeyNames.name(for: keyCode) }
}

struct Rule: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var from: KeyCombo
    var to: KeyCombo
    var enabled = true
    /// Also match when Shift is additionally held, passing Shift through (e.g. Shift+Home selects to line start).
    var includeShift = false
}

struct ExcludedApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

enum RuleMatcher {
    /// Exact modifier matches win over Shift pass-through matches.
    static func target(keyCode: UInt16, modifiers: Modifiers, rules: [Rule]) -> KeyCombo? {
        let candidates = rules.filter { $0.enabled && $0.from.keyCode == keyCode }
        if let exact = candidates.first(where: { $0.from.modifiers == modifiers }) {
            return exact.to
        }
        if let shifted = candidates.first(where: {
            $0.includeShift && !$0.from.modifiers.contains(.shift) && $0.from.modifiers.union(.shift) == modifiers
        }) {
            var target = shifted.to
            target.modifiers.insert(.shift)
            return target
        }
        return nil
    }
}

enum KeyCode {
    static let a: UInt16 = 0, s: UInt16 = 1, f: UInt16 = 3, z: UInt16 = 6, x: UInt16 = 7, c: UInt16 = 8
    static let v: UInt16 = 9, b: UInt16 = 11, w: UInt16 = 13, r: UInt16 = 15, y: UInt16 = 16, t: UInt16 = 17
    static let o: UInt16 = 31, u: UInt16 = 32, i: UInt16 = 34, p: UInt16 = 35, l: UInt16 = 37, n: UInt16 = 45
    static let backspace: UInt16 = 51, forwardDelete: UInt16 = 117
    static let home: UInt16 = 115, end: UInt16 = 119, pageUp: UInt16 = 116, pageDown: UInt16 = 121
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126

    static let arrows: Set<UInt16> = [left, right, down, up]
    static let fnNavigation: Set<UInt16> = [home, end, pageUp, pageDown, forwardDelete]
}

enum Defaults {
    static var rules: [Rule] {
        func ctrlToCmd(_ name: String, _ key: UInt16, shift: Bool = false) -> Rule {
            Rule(name: name, from: KeyCombo(keyCode: key, modifiers: .control),
                 to: KeyCombo(keyCode: key, modifiers: .command), includeShift: shift)
        }
        func rule(_ name: String, _ fromKey: UInt16, _ fromMods: Modifiers,
                  _ toKey: UInt16, _ toMods: Modifiers, shift: Bool = false) -> Rule {
            Rule(name: name, from: KeyCombo(keyCode: fromKey, modifiers: fromMods),
                 to: KeyCombo(keyCode: toKey, modifiers: toMods), includeShift: shift)
        }
        return [
            ctrlToCmd("Copy", KeyCode.c),
            ctrlToCmd("Paste", KeyCode.v),
            ctrlToCmd("Cut", KeyCode.x),
            ctrlToCmd("Select All", KeyCode.a),
            ctrlToCmd("Undo / Redo (with ⇧)", KeyCode.z, shift: true),
            rule("Redo", KeyCode.y, .control, KeyCode.z, [.command, .shift]),
            ctrlToCmd("Save / Save As (with ⇧)", KeyCode.s, shift: true),
            ctrlToCmd("Find", KeyCode.f),
            ctrlToCmd("New", KeyCode.n, shift: true),
            ctrlToCmd("Open", KeyCode.o),
            ctrlToCmd("Print", KeyCode.p),
            ctrlToCmd("New Tab / Reopen Tab (with ⇧)", KeyCode.t, shift: true),
            ctrlToCmd("Close Tab / Window", KeyCode.w),
            ctrlToCmd("Reload", KeyCode.r, shift: true),
            ctrlToCmd("Address Bar", KeyCode.l),
            ctrlToCmd("Bold", KeyCode.b),
            ctrlToCmd("Italic", KeyCode.i),
            ctrlToCmd("Underline", KeyCode.u),
            rule("Previous Word", KeyCode.left, .control, KeyCode.left, .option, shift: true),
            rule("Next Word", KeyCode.right, .control, KeyCode.right, .option, shift: true),
            rule("Line Start (Home)", KeyCode.home, [], KeyCode.left, .command, shift: true),
            rule("Line End (End)", KeyCode.end, [], KeyCode.right, .command, shift: true),
            rule("Document Start", KeyCode.home, .control, KeyCode.up, .command, shift: true),
            rule("Document End", KeyCode.end, .control, KeyCode.down, .command, shift: true),
            rule("Delete Previous Word", KeyCode.backspace, .control, KeyCode.backspace, .option),
            rule("Delete Next Word", KeyCode.forwardDelete, .control, KeyCode.forwardDelete, .option),
        ]
    }

    /// Terminals need a real Ctrl+C; VMs and remote desktops translate keys themselves.
    static let excludedApps: [ExcludedApp] = [
        ExcludedApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        ExcludedApp(bundleID: "com.googlecode.iterm2", name: "iTerm2"),
        ExcludedApp(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
        ExcludedApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
        ExcludedApp(bundleID: "net.kovidgoyal.kitty", name: "kitty"),
        ExcludedApp(bundleID: "org.alacritty", name: "Alacritty"),
        ExcludedApp(bundleID: "com.github.wez.wezterm", name: "WezTerm"),
        ExcludedApp(bundleID: "co.zeit.hyper", name: "Hyper"),
        ExcludedApp(bundleID: "org.tabby", name: "Tabby"),
        ExcludedApp(bundleID: "com.microsoft.rdc.macos", name: "Windows App / Remote Desktop"),
        ExcludedApp(bundleID: "com.parallels.desktop.console", name: "Parallels Desktop"),
        ExcludedApp(bundleID: "com.vmware.fusion", name: "VMware Fusion"),
        ExcludedApp(bundleID: "com.utmapp.UTM", name: "UTM"),
    ]
}

enum KeyNames {
    private static let special: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 76: "⌤",
        115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    static func name(for keyCode: UInt16) -> String {
        if let name = special[keyCode] { return name }
        return character(for: keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    /// Uses the current keyboard layout so labels match what's printed on the user's keys.
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let result = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
