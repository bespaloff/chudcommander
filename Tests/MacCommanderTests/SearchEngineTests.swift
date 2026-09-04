import Foundation
import Testing
@testable import MacCommander

@Suite("Search engine")
struct SearchEngineTests {
    @Test("Search combines name, content, recursion, and exclusions")
    func combinedSearch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("needle in a haystack".utf8).write(to: nested.appendingPathComponent("useful-note.txt"))
        try Data("needle".utf8).write(to: nested.appendingPathComponent("ignore-me.txt"))
        try Data("unrelated".utf8).write(to: root.appendingPathComponent("useful-other.txt"))

        var options = SearchOptions()
        options.nameQuery = "useful"
        options.contentQuery = "needle"
        options.excludedNames = "ignore-*"
        let results = try await SearchEngine.search(root: root, options: options)

        #expect(results.map(\.item.name) == ["useful-note.txt"])
    }

    @Test("Non-recursive search stays in the selected folder")
    func nonRecursive() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: nested.appendingPathComponent("deep.txt"))
        try Data().write(to: root.appendingPathComponent("top.txt"))

        var options = SearchOptions()
        options.recursive = false
        options.searchFolders = false
        let results = try await SearchEngine.search(root: root, options: options)
        #expect(results.map(\.item.name) == ["top.txt"])
    }
}
