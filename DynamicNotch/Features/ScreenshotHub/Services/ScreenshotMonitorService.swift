internal import AppKit
import Foundation
import Combine
import AVFoundation

final class ScreenshotMonitorService {
    var onScreenshotCaptured: ((NSImage, URL?, String) -> Void)?
    var onScreenRecordingCaptured: ((URL, NSImage, String) -> Void)?
    
    private(set) var userTargetDirectoryURL: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    
    private var originalScreenshotLocation: String?
    private var fileWatcherTimer: Timer?
    private let directoryWatcher = DirectoryEventWatcher()
    private var pendingScan: Task<Void, Never>?
    private var monitoringGeneration = 0
    private var knownFilePaths = Set<String>()
    private var isMonitoring = false
    private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount
    private var suppressUntil: Date = .distantPast
    private let fileManager = FileManager.default
    
    init() {
        self.originalScreenshotLocation = Self.getSystemScreenshotLocation()
        self.userTargetDirectoryURL = computeUserTargetDirectoryURL()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring(disableSystemThumbnail: Bool = true) {
        guard !AppEnvironment.isRunningTests, !isMonitoring else { return }
        isMonitoring = true
        
        self.originalScreenshotLocation = Self.getSystemScreenshotLocation()
        self.userTargetDirectoryURL = computeUserTargetDirectoryURL()
        self.lastPasteboardChangeCount = NSPasteboard.general.changeCount
        
        let stagingDir = rawStagingDirectoryURL()
        try? fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        primeBaseline()
        
        monitoringGeneration += 1
        directoryWatcher.onChange = { [weak self] in self?.scheduleEventScan() }
        updateDirectoryWatchers()
        // Slow recovery handles folder replacement, path-setting changes and missed events.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.updateDirectoryWatchers()
            self.scanNow()
        }
        timer.tolerance = 3
        RunLoop.main.add(timer, forMode: .common)
        fileWatcherTimer = timer
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitoringGeneration += 1
        pendingScan?.cancel(); pendingScan = nil
        directoryWatcher.stop()
        directoryWatcher.onChange = nil
        fileWatcherTimer?.invalidate()
        fileWatcherTimer = nil
    }
    
    private func updateDirectoryWatchers() {
        directoryWatcher.update(candidateScreenshotDirectories() + candidateScreenRecordingDirectories())
    }

    private func scheduleEventScan() {
        guard isMonitoring else { return }
        // Do not reset the debounce continuously while a recording is being written.
        guard pendingScan == nil else { return }
        let generation = monitoringGeneration
        pendingScan = Task { @MainActor [weak self] in
            // Retry partial image writes even when no further directory event is delivered.
            for delay in [0.15, 0.35, 0.7, 1.5, 3.0] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, self.isMonitoring, self.monitoringGeneration == generation else { return }
                self.updateDirectoryWatchers()
                self.scanNow()
            }
            self?.pendingScan = nil
        }
    }

    func updateLastPasteboardChangeCount() {
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }
    
    func suppressMonitoring(for duration: TimeInterval = 3.0) {
        suppressUntil = Date().addingTimeInterval(duration)
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }
    
    func rawStagingDirectoryURL() -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return caches.appendingPathComponent("com.Jackson.DynamicNotch/RawScreenshots")
    }
    
    func computeUserTargetDirectoryURL() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "settings.screenshot.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        if let original = Self.getSystemScreenshotLocation(), !original.isEmpty {
            let expanded = (original as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents
        }
        return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    }
    
    private func computeScreenRecordingTargetDirectoryURL() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "settings.screenRecording.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        return computeUserTargetDirectoryURL()
    }
    
    func candidateScreenshotDirectories() -> [URL] {
        var dirs: [URL] = []
        var seen = Set<String>()

        func addDir(_ url: URL?) {
            guard let url = url else { return }
            let std = url.standardizedFileURL
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: std.path, isDirectory: &isDir), isDir.boolValue {
                if !seen.contains(std.path) {
                    seen.insert(std.path)
                    dirs.append(std)
                }
            }
        }

        addDir(rawStagingDirectoryURL())

        if let customPath = UserDefaults.standard.string(forKey: "settings.screenshot.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            addDir(URL(fileURLWithPath: expanded))
        }

        let domain = "com.apple.screencapture" as CFString
        for key in ["location-screenshot", "location-last", "location"] {
            if let path = CFPreferencesCopyAppValue(key as CFString, domain) as? String, !path.isEmpty {
                let expanded = (path as NSString).expandingTildeInPath
                if !expanded.contains("com.Jackson.DynamicNotch") && !expanded.contains("RawScreenshots") {
                    addDir(URL(fileURLWithPath: expanded))
                }
            }
        }

        addDir(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)
        addDir(fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first)
        addDir(fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first)
        if let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first {
            addDir(pictures.appendingPathComponent("Screenshots"))
        }
        addDir(fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first)

        return dirs
    }

    func candidateScreenRecordingDirectories() -> [URL] {
        var dirs: [URL] = []
        var seen = Set<String>()

        func addDir(_ url: URL?) {
            guard let url = url else { return }
            let std = url.standardizedFileURL
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: std.path, isDirectory: &isDir), isDir.boolValue {
                if !seen.contains(std.path) {
                    seen.insert(std.path)
                    dirs.append(std)
                }
            }
        }

        addDir(rawStagingDirectoryURL())

        if let customPath = UserDefaults.standard.string(forKey: "settings.screenRecording.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            addDir(URL(fileURLWithPath: expanded))
        }

        let domain = "com.apple.screencapture" as CFString
        for key in ["location-screenrecording", "location-screenshot", "location-last", "location"] {
            if let path = CFPreferencesCopyAppValue(key as CFString, domain) as? String, !path.isEmpty {
                let expanded = (path as NSString).expandingTildeInPath
                if !expanded.contains("com.Jackson.DynamicNotch") && !expanded.contains("RawScreenshots") {
                    addDir(URL(fileURLWithPath: expanded))
                }
            }
        }

        addDir(fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first)
        addDir(fileManager.urls(for: .documentDirectory, in: .userDomainMask).first)
        addDir(fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first)
        addDir(fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first)

        return dirs
    }
    
    private func uniqueURL(for targetURL: URL) -> URL {
        guard fileManager.fileExists(atPath: targetURL.path) else { return targetURL }
        
        let dir = targetURL.deletingLastPathComponent()
        let ext = targetURL.pathExtension
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        
        var counter = 1
        var candidateURL = targetURL
        while fileManager.fileExists(atPath: candidateURL.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidateURL = dir.appendingPathComponent(newName)
            counter += 1
        }
        return candidateURL
    }
    
    static func isScreenshotFilename(_ filename: String) -> Bool {
        let normalized = filename.precomposedStringWithCanonicalMapping.lowercased()
        let isImage = normalized.hasSuffix(".png") || normalized.hasSuffix(".jpg") || normalized.hasSuffix(".jpeg") || normalized.hasSuffix(".heic") || normalized.hasSuffix(".tiff")
        guard isImage else { return false }
        return normalized.contains("screenshot") ||
            normalized.contains("screen shot") ||
            normalized.contains("스크린샷") ||
            normalized.contains("화면 캡처") ||
            normalized.contains("화면캡처") ||
            normalized.contains("캡처") ||
            normalized.contains("cleanshot") ||
            normalized.contains("shottr") ||
            normalized.contains("snagit") ||
            normalized.contains("screen_shot") ||
            normalized.contains("bildschirmfoto") ||
            normalized.contains("capture d") ||
            normalized.contains("captura de pantalla") ||
            normalized.contains("снимок экрана") ||
            normalized.contains("скриншот") ||
            normalized.contains("スクリーンショット") ||
            normalized.contains("屏幕快照") ||
            normalized.contains("截屏")
    }

    private func primeBaseline() {
        let dirs = candidateScreenshotDirectories() + candidateScreenRecordingDirectories()
        for dir in dirs {
            if let urls = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for url in urls {
                    knownFilePaths.insert(url.path)
                }
            }
        }
    }
    
    func scanNow() {
        scanForNewScreenshots()
        scanTargetDirectoryForRecordings()
    }

    private func scanForNewScreenshots() {
        guard Date() >= suppressUntil else { return }
        self.userTargetDirectoryURL = computeUserTargetDirectoryURL()
        let stagingDir = rawStagingDirectoryURL()
        let directoriesToScan = candidateScreenshotDirectories()

        let now = Date()
        for dir in directoriesToScan {
            let isStagingDir = dir.standardizedFileURL == stagingDir.standardizedFileURL
            guard let urls = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let path = url.path
                guard !knownFilePaths.contains(path) else { continue }

                let filename = url.lastPathComponent
                let lower = filename.precomposedStringWithCanonicalMapping.lowercased()

                if lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") || lower.contains("screen recording") || lower.contains("화면 기록") || lower.contains("запись экрана") {
                    guard isStagingDir,
                          let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                          resourceValues.isRegularFile == true else { continue }

                    let targetDir = computeScreenRecordingTargetDirectoryURL()
                    try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                    let destinationURL = uniqueURL(for: targetDir.appendingPathComponent(filename))
                    do {
                        try fileManager.moveItem(at: url, to: destinationURL)
                        knownFilePaths.insert(path)
                        knownFilePaths.insert(destinationURL.path)

                        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                            let thumbnail = Self.generateVideoThumbnail(for: destinationURL) ?? NSWorkspace.shared.icon(forFile: destinationURL.path)
                            DispatchQueue.main.async {
                                self?.onScreenRecordingCaptured?(destinationURL, thumbnail, filename)
                            }
                        }
                    } catch {
                        // File might be currently open/being written by screencapture, try again on next timer tick
                    }
                    continue
                }

                guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true,
                      let modDate = resourceValues.contentModificationDate,
                      now.timeIntervalSince(modDate) < 25.0 else {
                    knownFilePaths.insert(path)
                    continue
                }

                let matchesScreenshot = isStagingDir
                    ? (lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".heic") || Self.isScreenshotFilename(filename))
                    : Self.isScreenshotFilename(filename)

                if matchesScreenshot, let image = NSImage(contentsOf: url), image.size.width > 16, image.size.height > 16 {
                    knownFilePaths.insert(path)
                    lastPasteboardChangeCount = NSPasteboard.general.changeCount
                    DispatchQueue.main.async { [weak self] in
                        self?.onScreenshotCaptured?(image, url, filename)
                    }
                    return
                }
            }
        }
    }

    private func scanTargetDirectoryForRecordings() {
        let directoriesToScan = candidateScreenRecordingDirectories()
        let stagingDir = rawStagingDirectoryURL()

        let now = Date()
        for targetDir in directoriesToScan {
            guard targetDir != stagingDir else { continue }
            guard let urls = try? fileManager.contentsOfDirectory(
                at: targetDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls {
                let path = url.path
                guard !knownFilePaths.contains(path) else { continue }

                let filename = url.lastPathComponent
                let lower = filename.lowercased()
                guard lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") || lower.contains("screen recording") || lower.contains("화면 기록") || lower.contains("запись экрана") else {
                    continue
                }

                guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true,
                      let modDate = resourceValues.contentModificationDate,
                      now.timeIntervalSince(modDate) < 30.0 else {
                    knownFilePaths.insert(path)
                    continue
                }

                // Ensure the file is not currently locked/open for exclusive writing
                guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
                    continue
                }
                try? fileHandle.close()

                knownFilePaths.insert(path)

                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let thumbnail = Self.generateVideoThumbnail(for: url) ?? NSWorkspace.shared.icon(forFile: url.path)
                    DispatchQueue.main.async {
                        self?.onScreenRecordingCaptured?(url, thumbnail, filename)
                    }
                }
            }
        }
    }

    static func generateVideoThumbnail(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)

        let times = [
            CMTime(seconds: 0.5, preferredTimescale: 600),
            CMTime.zero,
            CMTime(seconds: 0.1, preferredTimescale: 600)
        ]

        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        return nil
    }
    
    func markPathAsKnown(_ path: String) {
        knownFilePaths.insert(path)
    }
    
    /// Configures system preference to hide or show the default floating screenshot thumbnail in the bottom-right corner of macOS.
    static func setSystemFloatingThumbnailEnabled(_ enabled: Bool) {
        let key = "show-thumbnail" as CFString
        let domain = "com.apple.screencapture" as CFString
        CFPreferencesSetValue(key, enabled as CFBoolean, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesAppSynchronize(domain)
    }
    
    static func getSystemScreenshotLocation() -> String? {
        let domain = "com.apple.screencapture" as CFString
        for key in ["location-screenshot", "location-last", "location"] {
            if let val = CFPreferencesCopyAppValue(key as CFString, domain) as? String,
               !val.isEmpty,
               !val.contains("RawScreenshots"),
               !val.contains("com.Jackson.DynamicNotch") {
                return val
            }
        }
        return nil
    }
    
    static func setSystemScreenshotLocation(_ path: String?) {
        let key = "location" as CFString
        let domain = "com.apple.screencapture" as CFString
        if let path = path {
            let expanded = (path as NSString).expandingTildeInPath
            CFPreferencesSetValue(key, expanded as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        } else {
            CFPreferencesSetValue(key, nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        CFPreferencesAppSynchronize(domain)
        
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["SystemUIServer"]
        try? task.run()
    }
}
