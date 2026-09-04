import AppKit

@MainActor
final class KeyboardEventMonitor {
    private var monitor: Any?
    private weak var state: AppState?

    init(state: AppState) { self.state = state }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let state = self.state else { return event }
            if NSApp.keyWindow?.attachedSheet != nil { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isEditingText = NSApp.keyWindow?.firstResponder is NSTextView
            let terminalHasFocus = state.leftPane.terminal.hasKeyboardFocus || state.rightPane.terminal.hasKeyboardFocus

            if terminalHasFocus {
                if event.keyCode == 118, modifiers.contains(.option) { // Option-F4 still closes the terminal.
                    state.toggleTerminal()
                    return nil
                }
                return event
            }

            if modifiers.contains(.command) {
                switch event.keyCode {
                case 33: // Command-[
                    state.activePane.goBack(); return nil
                case 30: // Command-]
                    state.activePane.goForward(); return nil
                case 18: // Command-1
                    state.activePane.viewMode = .list; return nil
                case 19: // Command-2
                    state.activePane.viewMode = .grid; return nil
                case 47 where modifiers.contains(.shift): // Command-Shift-.
                    state.activePane.showHidden.toggle()
                    state.activePane.reload()
                    return nil
                default:
                    break
                }
            }

            if !isEditingText, event.keyCode == 53, !state.activePane.filterQuery.isEmpty { // Escape
                state.activePane.clearFilter()
                return nil
            }

            if !isEditingText, event.keyCode == 51, !state.activePane.filterQuery.isEmpty { // Backspace
                state.activePane.deleteLastFilterCharacter()
                return nil
            }

            if !isEditingText, let text = filterText(from: event, startsNewFilter: state.activePane.filterQuery.isEmpty) {
                state.activePane.appendToFilter(text)
                return nil
            }

            switch event.keyCode {
            case 99: // F3
                state.quickLookSelection(); return nil
            case 118: // F4
                if modifiers.contains(.option) { state.toggleTerminal() }
                else { state.openSelection() }
                return nil
            case 96: // F5
                state.copySelection(); return nil
            case 97: // F6 / Shift-F6 rename
                if modifiers.contains(.shift) { state.requestRename() }
                else { state.moveSelection() }
                return nil
            case 98: // F7
                state.requestNewFolder(); return nil
            case 100: // F8
                state.requestTrash(); return nil
            case 48: // Tab always changes pane and hands focus to its file cursor
                if let window = NSApp.keyWindow {
                    window.endEditing(for: nil)
                    window.makeFirstResponder(window.contentView)
                }
                state.switchPane(); return nil
            case 49: // Space = Quick Look
                if isEditingText { return event }
                state.quickLookSelection(); return nil
            case 126: // Up Arrow
                if isEditingText { return event }
                state.activePane.moveCursor(.up); return nil
            case 125: // Down Arrow
                if isEditingText { return event }
                state.activePane.moveCursor(.down); return nil
            case 123: // Left Arrow
                if isEditingText { return event }
                state.activePane.moveCursor(.left); return nil
            case 124: // Right Arrow
                if isEditingText { return event }
                state.activePane.moveCursor(.right); return nil
            case 115: // Home
                if isEditingText { return event }
                state.activePane.moveCursor(.first); return nil
            case 119: // End
                if isEditingText { return event }
                state.activePane.moveCursor(.last); return nil
            case 116: // Page Up
                if isEditingText { return event }
                state.activePane.moveCursor(.pageUp); return nil
            case 121: // Page Down
                if isEditingText { return event }
                state.activePane.moveCursor(.pageDown); return nil
            case 36, 76: // Return / keypad Enter
                if isEditingText { return event }
                state.activateCursor(); return nil
            case 51: // Backspace = parent folder
                if isEditingText { return event }
                state.activePane.goUp(); return nil
            default:
                return event
            }
        }
    }

    func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func filterText(from event: NSEvent, startsNewFilter: Bool) -> String? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.contains(.command), !modifiers.contains(.control),
              let text = event.characters, !text.isEmpty else { return nil }

        let allowedCharacters = CharacterSet.alphanumerics
            .union(.punctuationCharacters)
            .union(.symbols)
            .union(.whitespaces)
        let scalars = text.unicodeScalars
        guard scalars.allSatisfy({
            !CharacterSet.controlCharacters.contains($0) && allowedCharacters.contains($0)
        }) else { return nil }

        if startsNewFilter && scalars.allSatisfy({ CharacterSet.whitespaces.contains($0) }) {
            return nil
        }
        return text
    }

}
