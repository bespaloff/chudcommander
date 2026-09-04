import Foundation

enum FolderSizeState: Equatable, Sendable {
    case calculating
    case ready(Int64)
    case unavailable

    var bytes: Int64? {
        guard case .ready(let bytes) = self else { return nil }
        return bytes
    }
}

actor FolderSizeService {
    private struct CacheEntry: Sendable {
        let bytes: Int64
        let savedAt: Date
    }

    private let cacheLifetime: TimeInterval
    private var cache: [URL: CacheEntry] = [:]
    private var inFlight: [URL: Task<Int64?, Never>] = [:]

    init(cacheLifetime: TimeInterval = 300) {
        self.cacheLifetime = cacheLifetime
    }

    func cachedSizes(for urls: [URL]) -> [URL: Int64] {
        purgeExpiredEntries()
        return urls.reduce(into: [:]) { result, url in
            let key = url.standardizedFileURL
            if let entry = cache[key] {
                result[key] = entry.bytes
            }
        }
    }

    func size(of folder: URL, forceRefresh: Bool = false) async -> Int64? {
        let key = folder.standardizedFileURL
        purgeExpiredEntries()

        if !forceRefresh, let cached = cache[key] {
            return cached.bytes
        }
        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task.detached(priority: .utility) {
            Self.calculateSize(of: key)
        }
        inFlight[key] = task
        let bytes = await task.value
        inFlight[key] = nil
        if let bytes {
            cache[key] = CacheEntry(bytes: bytes, savedAt: Date())
        }
        return bytes
    }

    private func purgeExpiredEntries() {
        let cutoff = Date().addingTimeInterval(-cacheLifetime)
        cache = cache.filter { $0.value.savedAt >= cutoff }
    }

    private nonisolated static func calculateSize(of folder: URL) -> Int64? {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileSizeKey,
            .fileSizeKey
        ]
        var encounteredError = false
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in
                encounteredError = true
                return true
            }
        ) else { return nil }

        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                encounteredError = true
                continue
            }
            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            guard values.isDirectory != true else { continue }

            let bytes = Int64(values.totalFileSize ?? values.fileSize ?? 0)
            let (sum, overflow) = total.addingReportingOverflow(bytes)
            total = overflow ? Int64.max : sum
        }
        return encounteredError ? nil : total
    }
}
