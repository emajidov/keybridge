import AppKit
import CoreGraphics

/// Intercepts key events system-wide and replaces matching shortcuts with their configured targets.
final class KeyRemapper {
    var rules: [Rule] = []
    var excludedBundleIDs: Set<String> = []
    /// Set while recording a shortcut in the UI so the user's real keys are captured.
    var isPaused = false
    var frontmostBundleID: String?

    private(set) var isRunning = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Physical key -> remapped combo, so the key-up matches the key-down even if modifiers were released first.
    private var pressed: [UInt16: KeyCombo] = [:]
    /// Private state keeps the physically held Ctrl out of synthesized events.
    private let eventSource = CGEventSource(stateID: .privateState)

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeyRemapper>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        isRunning = true
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        runLoopSource = nil
        pressed.removeAll()
        isRunning = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .keyDown, .keyUp:
            break
        default:
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isKeyDown = type == .keyDown
        let target: KeyCombo?
        if isKeyDown {
            let excluded = frontmostBundleID.map { excludedBundleIDs.contains($0) } ?? false
            target = (isPaused || excluded) ? nil
                : RuleMatcher.target(keyCode: keyCode, modifiers: Modifiers(cgFlags: event.flags), rules: rules)
            pressed[keyCode] = target
        } else {
            target = pressed.removeValue(forKey: keyCode)
        }

        guard let target, let replacement = makeEvent(target, keyDown: isKeyDown, original: event) else {
            return Unmanaged.passUnretained(event)
        }
        return Unmanaged.passRetained(replacement)
    }

    /// A fresh event (rather than mutating the original) gets correct characters for the new key and modifiers.
    private func makeEvent(_ combo: KeyCombo, keyDown: Bool, original: CGEvent) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: combo.keyCode, keyDown: keyDown) else {
            return nil
        }
        var flags = combo.modifiers.cgFlags
        if KeyCode.arrows.contains(combo.keyCode) {
            flags.insert([.maskNumericPad, .maskSecondaryFn])
        } else if KeyCode.fnNavigation.contains(combo.keyCode) {
            flags.insert(.maskSecondaryFn)
        }
        event.flags = flags
        event.setIntegerValueField(.keyboardEventAutorepeat, value: original.getIntegerValueField(.keyboardEventAutorepeat))
        event.timestamp = original.timestamp
        return event
    }
}
