import Foundation

enum FileSystemService {
    static func contents(of directory: URL, showHidden: Bool) throws -> [FileItem] {
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(FileItem.standardKeys),
            options: options
        )
        return urls.compactMap { FileItem.load(url: $0) }
    }

    static func sorted(
        _ items: [FileItem],
        by sort: FileSort,
        ascending: Bool,
        folderSizes: [URL: FolderSizeState] = [:]
    ) -> [FileItem] {
        items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            let result: ComparisonResult
            switch sort {
            case .name:
                result = lhs.name.localizedStandardCompare(rhs.name)
            case .kind:
                result = lhs.kind.localizedStandardCompare(rhs.kind)
            case .size:
                let lhsSize = lhs.isDirectory ? folderSizes[lhs.url.standardizedFileURL]?.bytes ?? 0 : lhs.size
                let rhsSize = rhs.isDirectory ? folderSizes[rhs.url.standardizedFileURL]?.bytes ?? 0 : rhs.size
                result = lhsSize == rhsSize ? lhs.name.localizedStandardCompare(rhs.name) : (lhsSize < rhsSize ? .orderedAscending : .orderedDescending)
            case .modified:
                result = compare(lhs.modifiedAt, rhs.modifiedAt, lhs.name, rhs.name)
            case .created:
                result = compare(lhs.createdAt, rhs.createdAt, lhs.name, rhs.name)
            case .lastOpened:
                result = compare(lhs.lastOpenedAt, rhs.lastOpenedAt, lhs.name, rhs.name)
            case .added:
                result = compare(lhs.addedAt, rhs.addedAt, lhs.name, rhs.name)
            case .version:
                result = compare(lhs.version, rhs.version, lhs.name, rhs.name)
            case .comments:
                result = compare(lhs.comments, rhs.comments, lhs.name, rhs.name)
            case .tags:
                result = compare(lhs.formattedTags, rhs.formattedTags, lhs.name, rhs.name)
            case .sharedBy:
                result = compare(lhs.sharedBy, rhs.sharedBy, lhs.name, rhs.name)
            case .iCloudStatus:
                result = compare(lhs.iCloudStatus, rhs.iCloudStatus, lhs.name, rhs.name)
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private static func compare(_ lhs: Date?, _ rhs: Date?, _ lhsName: String, _ rhsName: String) -> ComparisonResult {
        let lhs = lhs ?? .distantPast
        let rhs = rhs ?? .distantPast
        return lhs == rhs ? lhsName.localizedStandardCompare(rhsName) : (lhs < rhs ? .orderedAscending : .orderedDescending)
    }

    private static func compare(_ lhs: String, _ rhs: String, _ lhsName: String, _ rhsName: String) -> ComparisonResult {
        let result = lhs.localizedStandardCompare(rhs)
        return result == .orderedSame ? lhsName.localizedStandardCompare(rhsName) : result
    }

    static func uniqueDestination(for source: URL, in directory: URL) -> URL {
        let proposed = directory.appendingPathComponent(source.lastPathComponent)
        guard FileManager.default.fileExists(atPath: proposed.path) else { return proposed }

        let ext = source.pathExtension
        let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        var counter = 2
        while true {
            let suffix = counter == 2 ? " copy" : " copy \(counter)"
            let filename = ext.isEmpty ? stem + suffix : stem + suffix + "." + ext
            let candidate = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }

    static func expandedURL(from input: String, relativeTo base: URL) -> URL {
        let expanded = NSString(string: input).expandingTildeInPath
        if expanded.hasPrefix("/") { return URL(fileURLWithPath: expanded).standardizedFileURL }
        return base.appendingPathComponent(expanded).standardizedFileURL
    }
}
