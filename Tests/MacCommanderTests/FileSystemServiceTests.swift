import Foundation
import Testing
@testable import MacCommander

@Suite("File system utilities")
struct FileSystemServiceTests {
    @Test("A conflicting destination gets a non-destructive copy name")
    func uniqueDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = root.appendingPathComponent("report.txt")
        try Data().write(to: existing)

        let result = FileSystemService.uniqueDestination(for: existing, in: root)
        #expect(result.lastPathComponent == "report copy.txt")
    }

    @Test("Relative and tilde paths expand correctly")
    func pathExpansion() {
        let base = URL(fileURLWithPath: "/tmp/example")
        #expect(FileSystemService.expandedURL(from: "child", relativeTo: base).path == "/tmp/example/child")
        #expect(FileSystemService.expandedURL(from: "~/Documents", relativeTo: base).path.hasSuffix("/Documents"))
    }

    @Test("Folder sizes include nested files and use the short-lived cache")
    func folderSizes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 12).write(to: root.appendingPathComponent("one.bin"))
        try Data(repeating: 2, count: 30).write(to: nested.appendingPathComponent("two.bin"))

        let service = FolderSizeService(cacheLifetime: 60)
        #expect(await service.size(of: root) == 42)

        try Data(repeating: 3, count: 8).write(to: nested.appendingPathComponent("three.bin"))
        #expect(await service.size(of: root) == 42)
        #expect(await service.size(of: root, forceRefresh: true) == 50)
    }

    @Test("Calculated folder sizes participate in size sorting")
    func folderSizeSorting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let smaller = root.appendingPathComponent("smaller", isDirectory: true)
        let larger = root.appendingPathComponent("larger", isDirectory: true)
        try FileManager.default.createDirectory(at: smaller, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: larger, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let items = try FileSystemService.contents(of: root, showHidden: true)
        let sorted = FileSystemService.sorted(
            items,
            by: .size,
            ascending: true,
            folderSizes: [
                smaller.standardizedFileURL: .ready(10),
                larger.standardizedFileURL: .ready(20)
            ]
        )

        #expect(sorted.map(\.name) == ["smaller", "larger"])
    }
}
