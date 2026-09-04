import Testing
@testable import MacCommander

@Suite("Control tooltips")
struct ControlTooltipTests {
    @Test("A wired shortcut is included in the tooltip")
    func includesShortcut() {
        #expect(ControlTooltip.text("Find files", shortcut: "⌘F") == "Find files\nShortcut: ⌘F")
    }

    @Test("Controls without shortcuts only describe their action")
    func omitsMissingShortcut() {
        #expect(ControlTooltip.text("Choose visible columns") == "Choose visible columns")
    }
}
