import AppKit
import Combine
import Foundation
@preconcurrency import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, @unchecked Sendable, LocalProcessTerminalViewDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var title = "Terminal"
    var onDirectoryChange: ((URL) -> Void)?

    let terminalView: LocalProcessTerminalView

    init() {
        let options = TerminalOptions(
            cursorStyle: .steadyBar,
            scrollback: 10_000,
            regionalIndicatorWidth: .narrow
        )
        terminalView = LocalProcessTerminalView(
            frame: .zero,
            font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            options: options
        )
        terminalView.configureNativeColors()
        terminalView.caretColor = .controlAccentColor
        terminalView.processDelegate = self
        terminalView.autoresizingMask = [.width, .height]
    }

    func start(in directory: URL) {
        if isRunning {
            changeDirectory(to: directory)
            return
        }

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        // This opts into macOS's system zsh integration, including OSC 7
        // working-directory reports, without emulating Terminal.app itself.
        environment["TERM_PROGRAM"] = "Apple_Terminal"
        environment.removeValue(forKey: "TERM_SESSION_ID")

        let variables = environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: variables,
            execName: "-zsh",
            currentDirectory: directory.standardizedFileURL.path
        )
        isRunning = true
    }

    func changeDirectory(to directory: URL) {
        guard isRunning else { return }
        let escaped = directory.path.replacingOccurrences(of: "'", with: "'\\''")
        send("cd -- '\(escaped)'\n")
    }

    func clear() {
        terminalView.getTerminal().clearScrollback()
        send(bytes: [0x0c]) // Control-L clears the visible shell screen.
        focus()
    }

    func focus() {
        guard let window = terminalView.window else { return }
        window.makeFirstResponder(terminalView)
    }

    var hasKeyboardFocus: Bool {
        guard let responder = terminalView.window?.firstResponder else { return false }
        if responder === terminalView { return true }
        guard let responderView = responder as? NSView else { return false }
        return responderView.isDescendant(of: terminalView)
    }

    func stop() {
        guard isRunning else { return }
        terminalView.terminate()
        isRunning = false
    }

    private func send(_ string: String) {
        send(bytes: Array(string.utf8))
    }

    private func send(bytes: [UInt8]) {
        terminalView.send(source: terminalView, data: bytes[...])
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor [weak self] in
            self?.title = title.isEmpty ? "Terminal" : title
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        guard let directory,
              let url = URL(string: directory),
              url.isFileURL else { return }
        // Strip OSC 7's optional host so it compares equal to pane file URLs.
        let localURL = URL(fileURLWithPath: url.path).standardizedFileURL
        Task { @MainActor [weak self] in
            self?.onDirectoryChange?(localURL)
        }
    }

    nonisolated func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            self?.isRunning = false
            self?.title = "Terminal — exited"
        }
    }
}
