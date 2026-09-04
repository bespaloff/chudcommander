import Foundation

struct SearchOptions: Sendable, Equatable {
    var nameQuery = ""
    var contentQuery = ""
    var excludedNames = ""
    var recursive = true
    var includeHidden = false
    var caseSensitive = false
    var useRegularExpression = false
    var searchFiles = true
    var searchFolders = true
    var maximumFileSize: Int64 = 64 * 1_024 * 1_024
}

struct SearchMatch: Identifiable, Hashable, Sendable {
    let item: FileItem
    let matchedContent: Bool
    var id: URL { item.url }
}

enum SearchEngine {
    static func search(root: URL, options: SearchOptions) async throws -> [SearchMatch] {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let keys = Array(FileItem.standardKeys)
            var enumerationOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if !options.includeHidden { enumerationOptions.insert(.skipsHiddenFiles) }
            var candidateURLs: [URL] = []

            if options.recursive {
                if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: enumerationOptions) {
                    while let url = enumerator.nextObject() as? URL {
                        try Task.checkCancellation()
                        candidateURLs.append(url)
                    }
                }
            } else {
                candidateURLs = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: enumerationOptions)
            }

            let nameRegex = try compileRegex(options.nameQuery, enabled: options.useRegularExpression, caseSensitive: options.caseSensitive)
            let exclusions = options.excludedNames
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var matches: [SearchMatch] = []
            for url in candidateURLs {
                try Task.checkCancellation()
                guard let item = FileItem.load(url: url) else { continue }
                guard (item.isDirectory && options.searchFolders) || (!item.isDirectory && options.searchFiles) else { continue }
                guard exclusions.allSatisfy({ !wildcard($0, matches: item.name, caseSensitive: options.caseSensitive) }) else { continue }
                guard nameMatches(item.name, query: options.nameQuery, regex: nameRegex, caseSensitive: options.caseSensitive) else { continue }

                var contentMatched = false
                if !options.contentQuery.isEmpty {
                    guard !item.isDirectory, item.size <= options.maximumFileSize else { continue }
                    contentMatched = try containsContent(url: url, query: options.contentQuery, caseSensitive: options.caseSensitive, regex: options.useRegularExpression)
                    guard contentMatched else { continue }
                }
                matches.append(SearchMatch(item: item, matchedContent: contentMatched))
            }
            return matches.sorted { $0.item.url.path.localizedStandardCompare($1.item.url.path) == .orderedAscending }
        }.value
    }

    private static func compileRegex(_ pattern: String, enabled: Bool, caseSensitive: Bool) throws -> NSRegularExpression? {
        guard enabled, !pattern.isEmpty else { return nil }
        return try NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    private static func nameMatches(_ name: String, query: String, regex: NSRegularExpression?, caseSensitive: Bool) -> Bool {
        guard !query.isEmpty else { return true }
        if let regex {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            return regex.firstMatch(in: name, range: range) != nil
        }
        return name.range(of: query, options: caseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func wildcard(_ pattern: String, matches value: String, caseSensitive: Bool) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        guard let regex = try? NSRegularExpression(pattern: "^\(escaped)$", options: caseSensitive ? [] : [.caseInsensitive]) else { return false }
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value)) != nil
    }

    private static func containsContent(url: URL, query: String, caseSensitive: Bool, regex: Bool) throws -> Bool {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        if data.prefix(8_192).contains(0) { return false }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return false }
        if regex {
            let expression = try NSRegularExpression(pattern: query, options: caseSensitive ? [] : [.caseInsensitive])
            return expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
        }
        return text.range(of: query, options: caseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
