import Foundation

enum FullDiskAccessAuthorization {
    private static let probeURLs: [URL] = [
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/ModeConfigurations.json"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/CloudTabs.db"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
        URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
    ]

    private static let probeDirectories: [URL] = [
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB"),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
    ]

    static func hasPermission() -> Bool {
        guard !AppEnvironment.isRunningTests else { return false }

        for url in probeURLs {
            if canReadProtectedResource(at: url) {
                return true
            }
        }

        for directoryURL in probeDirectories {
            if (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) != nil {
                return true
            }
        }

        return false
    }

    private static func canReadProtectedResource(at url: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
            return true
        } catch {
            return false
        }
    }
}
