import Foundation

nonisolated enum DownloadFolderAuthorization {
    static let browserMetadataKey = "settings.downloads.browserMetadata.enabled"
    static let bookmarkKey = "settings.downloads.authorizedFolderBookmark"
    static func resolve(_ data: Data) -> URL? {
        guard !data.isEmpty else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
    static func bookmark(for directory: URL) throws -> Data {
        try directory.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
