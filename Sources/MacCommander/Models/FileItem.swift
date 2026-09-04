import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let isHidden: Bool
    let size: Int64
    let modifiedAt: Date?
    let createdAt: Date?
    let lastOpenedAt: Date?
    let addedAt: Date?
    let kind: String
    let version: String
    let comments: String
    let tags: [String]
    let sharedBy: String
    let iCloudStatus: String
    let isParentEntry: Bool

    var id: URL { url }
    var fileExtension: String { url.pathExtension.lowercased() }

    var formattedSize: String {
        guard !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedModifiedDate: String { Self.format(date: modifiedAt) }
    var formattedCreatedDate: String { Self.format(date: createdAt) }
    var formattedLastOpenedDate: String { Self.format(date: lastOpenedAt) }
    var formattedAddedDate: String { Self.format(date: addedAt) }
    var formattedTags: String { tags.joined(separator: ", ") }

    static func load(url: URL, resourceKeys: Set<URLResourceKey> = standardKeys) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
        let isDirectory = values.isDirectory ?? false
        let type = values.contentType
        let kind: String
        if isDirectory {
            kind = values.isPackage == true ? "Package" : "Folder"
        } else if let localized = type?.localizedDescription {
            kind = localized
        } else if url.pathExtension.isEmpty {
            kind = "Document"
        } else {
            kind = "\(url.pathExtension.uppercased()) file"
        }
        let spotlight = spotlightMetadata(for: url)

        return FileItem(
            url: url,
            name: values.name ?? url.lastPathComponent,
            isDirectory: isDirectory,
            isPackage: values.isPackage ?? false,
            isHidden: values.isHidden ?? url.lastPathComponent.hasPrefix("."),
            size: Int64(values.fileSize ?? 0),
            modifiedAt: values.contentModificationDate,
            createdAt: values.creationDate,
            lastOpenedAt: spotlight.lastOpenedAt ?? values.contentAccessDate,
            addedAt: spotlight.addedAt ?? values.addedToDirectoryDate,
            kind: kind,
            version: spotlight.version,
            comments: spotlight.comments,
            tags: values.tagNames ?? [],
            sharedBy: sharedBy(from: values),
            iCloudStatus: iCloudStatus(from: values),
            isParentEntry: false
        )
    }

    static func parent(of location: URL) -> FileItem? {
        guard location.path != "/" else { return nil }
        let url = location.deletingLastPathComponent().standardizedFileURL
        return FileItem(
            url: url,
            name: "..",
            isDirectory: true,
            isPackage: false,
            isHidden: false,
            size: 0,
            modifiedAt: nil,
            createdAt: nil,
            lastOpenedAt: nil,
            addedAt: nil,
            kind: "Parent folder",
            version: "",
            comments: "",
            tags: [],
            sharedBy: "",
            iCloudStatus: "",
            isParentEntry: true
        )
    }

    static let standardKeys: Set<URLResourceKey> = [
        .nameKey, .isDirectoryKey, .isPackageKey, .isHiddenKey, .fileSizeKey,
        .contentModificationDateKey, .creationDateKey, .contentAccessDateKey,
        .addedToDirectoryDateKey, .contentTypeKey, .tagNamesKey,
        .isUbiquitousItemKey, .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemIsUploadingKey, .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemDownloadingErrorKey, .ubiquitousItemUploadingErrorKey,
        .ubiquitousItemIsSharedKey, .ubiquitousSharedItemCurrentUserRoleKey,
        .ubiquitousSharedItemOwnerNameComponentsKey
    ]

    private static func format(date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func spotlightMetadata(for url: URL) -> (
        comments: String,
        version: String,
        lastOpenedAt: Date?,
        addedAt: Date?
    ) {
        guard
            let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
            let attributes = MDItemCopyAttributes(
                item,
                [
                    kMDItemFinderComment!,
                    kMDItemVersion!,
                    kMDItemLastUsedDate!,
                    kMDItemDateAdded!
                ] as CFArray
            ) as? [String: Any]
        else { return ("", "", nil, nil) }

        return (
            normalizedMetadataString(attributes[kMDItemFinderComment as String] as? String),
            normalizedMetadataString(attributes[kMDItemVersion as String] as? String),
            attributes[kMDItemLastUsedDate as String] as? Date,
            attributes[kMDItemDateAdded as String] as? Date
        )
    }

    private static func normalizedMetadataString(_ value: String?) -> String {
        value?.split(whereSeparator: \Character.isWhitespace).joined(separator: " ") ?? ""
    }

    private static func sharedBy(from values: URLResourceValues) -> String {
        guard values.ubiquitousItemIsShared == true else { return "" }
        if values.ubiquitousSharedItemCurrentUserRole == .owner { return "Me" }
        if let owner = values.ubiquitousSharedItemOwnerNameComponents {
            return PersonNameComponentsFormatter.localizedString(from: owner, style: .default)
        }
        return "Shared"
    }

    private static func iCloudStatus(from values: URLResourceValues) -> String {
        guard values.isUbiquitousItem == true else { return "" }
        if values.ubiquitousItemDownloadingError != nil || values.ubiquitousItemUploadingError != nil {
            return "Error"
        }
        if values.ubiquitousItemIsDownloading == true { return "Downloading" }
        if values.ubiquitousItemIsUploading == true { return "Uploading" }

        return switch values.ubiquitousItemDownloadingStatus {
        case .notDownloaded: "In iCloud"
        case .downloaded: "Downloaded"
        case .current: "Current"
        default: ""
        }
    }
}

enum CursorMovement: Sendable {
    case previous
    case next
    case left
    case right
    case up
    case down
    case first
    case last
    case pageUp
    case pageDown
}

enum FileSort: String, CaseIterable, Sendable {
    case name = "Name"
    case sharedBy = "Shared By"
    case modified = "Date Modified"
    case created = "Date Created"
    case lastOpened = "Date Last Opened"
    case size = "Size"
    case version = "Version"
    case kind = "Kind"
    case comments = "Comments"
    case tags = "Tags"
    case added = "Date Added"
    case iCloudStatus = "iCloud Status"
}

enum FileListColumn: String, CaseIterable, Hashable, Identifiable, Sendable {
    case sharedBy = "Shared By"
    case modified = "Date Modified"
    case created = "Date Created"
    case lastOpened = "Date Last Opened"
    case size = "Size"
    case version = "Version"
    case kind = "Kind"
    case comments = "Comments"
    case tags = "Tags"
    case added = "Date Added"
    case iCloudStatus = "iCloud Status"

    var id: Self { self }

    static let defaults: Set<Self> = [.kind, .size, .modified]

    var sort: FileSort {
        switch self {
        case .sharedBy: .sharedBy
        case .modified: .modified
        case .created: .created
        case .lastOpened: .lastOpened
        case .size: .size
        case .version: .version
        case .kind: .kind
        case .comments: .comments
        case .tags: .tags
        case .added: .added
        case .iCloudStatus: .iCloudStatus
        }
    }
}

enum PaneViewMode: String, CaseIterable, Sendable {
    case list
    case grid

    var symbol: String { self == .list ? "list.bullet" : "square.grid.2x2" }
}
