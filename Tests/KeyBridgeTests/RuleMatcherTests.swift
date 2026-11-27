import Testing
@testable import KeyBridge

struct RuleMatcherTests {
    let copy = Rule(name: "Copy", from: KeyCombo(keyCode: KeyCode.c, modifiers: .control),
                    to: KeyCombo(keyCode: KeyCode.c, modifiers: .command))
    let home = Rule(name: "Home", from: KeyCombo(keyCode: KeyCode.home, modifiers: []),
                    to: KeyCombo(keyCode: KeyCode.left, modifiers: .command), includeShift: true)

    @Test func exactMatch() {
        #expect(RuleMatcher.target(keyCode: KeyCode.c, modifiers: .control, rules: [copy])
            == KeyCombo(keyCode: KeyCode.c, modifiers: .command))
    }

    @Test func extraModifiersDoNotMatchWithoutShiftPassThrough() {
        #expect(RuleMatcher.target(keyCode: KeyCode.c, modifiers: [.control, .shift], rules: [copy]) == nil)
        #expect(RuleMatcher.target(keyCode: KeyCode.c, modifiers: [], rules: [copy]) == nil)
    }

    @Test func shiftPassThrough() {
        #expect(RuleMatcher.target(keyCode: KeyCode.home, modifiers: .shift, rules: [home])
            == KeyCombo(keyCode: KeyCode.left, modifiers: [.command, .shift]))
    }

    @Test func exactRuleWinsOverShiftPassThrough() {
        let undo = Rule(name: "Undo", from: KeyCombo(keyCode: KeyCode.z, modifiers: .control),
                        to: KeyCombo(keyCode: KeyCode.z, modifiers: .command), includeShift: true)
        let custom = Rule(name: "Custom", from: KeyCombo(keyCode: KeyCode.z, modifiers: [.control, .shift]),
                          to: KeyCombo(keyCode: KeyCode.y, modifiers: .command))
        #expect(RuleMatcher.target(keyCode: KeyCode.z, modifiers: [.control, .shift], rules: [undo, custom])
            == KeyCombo(keyCode: KeyCode.y, modifiers: .command))
    }

    @Test func disabledRuleIgnored() {
        var disabled = copy
        disabled.enabled = false
        #expect(RuleMatcher.target(keyCode: KeyCode.c, modifiers: .control, rules: [disabled]) == nil)
    }
}
