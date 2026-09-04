import SwiftUI

enum ControlTooltip {
    static func text(_ description: String, shortcut: String? = nil) -> String {
        guard let shortcut, !shortcut.isEmpty else { return description }
        return "\(description)\nShortcut: \(shortcut)"
    }
}

extension View {
    func controlTooltip(_ description: String, shortcut: String? = nil) -> some View {
        help(ControlTooltip.text(description, shortcut: shortcut))
    }
}
