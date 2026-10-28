internal import AppKit
import Combine
import QuickLookUI

@MainActor
final class ScreenshotViewModel: ObservableObject {
    static let maxHistoryCount = 24

    @Published var activeScreenshot: ScreenshotModel?
    @Published private(set) var history: [ScreenshotModel] = []
    @Published var selectedHistoryItemID: UUID?
    
    var onScreenshotReady: ((ScreenshotModel) -> Void)?
    var onScreenshotDismissed: (() -> Void)?
    var onScreenRecordingCaptured: ((URL, NSImage, String) -> Void)? {
        get { monitorService.onScreenRecordingCaptured }
        set { monitorService.onScreenRecordingCaptured = newValue }
    }
    
    func scanNow() {
        monitorService.scanNow()
    }
    
    var savedLocation: String {
        let dirURL = monitorService.userTargetDirectoryURL
        let name = fileManager.displayName(atPath: dirURL.path)
        return name.isEmpty ? dirURL.lastPathComponent : name
    }
    
    private(set) var isDropped = false
    private(set) var isDeleted = false
    private(set) var isSavedToDisk = false
    private(set) var isCopied = false
    
    private var lastProcessedDate: Date?
    private let monitorService: ScreenshotMonitorService
    private let ocrService: OCRService
    private let fileManager = FileManager.default
    
    init(monitorService: ScreenshotMonitorService? = nil,
         ocrService: OCRService? = nil) {
        self.monitorService = monitorService ?? ScreenshotMonitorService()
        self.ocrService = ocrService ?? .shared
        
        setupMonitoring()
        if !AppEnvironment.isRunningTests {
            preloadRecentScreenshots()
        }
    }
    
    func startMonitoring(disableSystemThumbnail: Bool = true) {
        monitorService.startMonitoring(disableSystemThumbnail: disableSystemThumbnail)
    }
    
    func stopMonitoring() {
        monitorService.stopMonitoring()
    }
    
    func processNewScreenshot(image: NSImage, fileURL: URL?, fileName: String) {
        let now = Date()
        if let last = lastProcessedDate, now.timeIntervalSince(last) < 0.8 {
            return
        }
        lastProcessedDate = now
        
        isDropped = false
        isDeleted = false
        isSavedToDisk = false
        isCopied = false
        
        let stagingDir = monitorService.rawStagingDirectoryURL()
        try? fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        let tempURL: URL
        if let originalURL = fileURL {
            tempURL = originalURL
        } else {
            let generatedTempURL = stagingDir.appendingPathComponent("Screenshot_\(Int(Date().timeIntervalSince1970)).png")
            writePNG(image: image, to: generatedTempURL)
            tempURL = generatedTempURL
        }
        
        let targetDir = monitorService.userTargetDirectoryURL
        let name = fileName.hasSuffix(".png") ? fileName : "\(fileName).png"
        let targetURL: URL
        if let originalURL = fileURL,
           originalURL.deletingLastPathComponent().standardizedFileURL == targetDir.standardizedFileURL {
            targetURL = originalURL
            isSavedToDisk = true
        } else {
            targetURL = targetDir.appendingPathComponent(name)
        }
        
        let model = ScreenshotModel(
            image: image,
            fileURL: tempURL,
            tempFileURL: tempURL,
            targetDestinationURL: targetURL,
            fileName: fileName,
            recognizedText: "",
            isRecognizing: true,
            timestamp: Date()
        )
        
        self.activeScreenshot = model
        self.recordInHistory(model)
        self.onScreenshotReady?(model)
        
        Task { @MainActor [weak self] in
            let extractedText = await self?.ocrService.recognizeText(in: image) ?? ""
            guard let self else { return }
            if var current = self.activeScreenshot, current.id == model.id {
                current.recognizedText = extractedText
                current.isRecognizing = false
                self.activeScreenshot = current
            }
            if let idx = self.history.firstIndex(where: { $0.id == model.id }) {
                self.history[idx].recognizedText = extractedText
                self.history[idx].isRecognizing = false
            }
        }
    }

    private func recordInHistory(_ model: ScreenshotModel) {
        history.removeAll { existing in
            if existing.id == model.id { return true }
            if let a = existing.targetDestinationURL?.standardizedFileURL,
               let b = model.targetDestinationURL?.standardizedFileURL,
               a == b {
                return true
            }
            return false
        }
        history.insert(model, at: 0)
        if history.count > Self.maxHistoryCount {
            history.removeLast(history.count - Self.maxHistoryCount)
        }
        if selectedHistoryItemID == nil {
            selectedHistoryItemID = model.id
        }
    }

    func preloadRecentScreenshots() {
        var dirs = [monitorService.userTargetDirectoryURL, monitorService.rawStagingDirectoryURL()]
        if let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
           !dirs.contains(where: { $0.standardizedFileURL == desktop.standardizedFileURL }) {
            dirs.append(desktop)
        }

        var candidateFiles: [(url: URL, date: Date)] = []
        var seenPaths = Set<String>()
        for dir in dirs {
            let isStaging = dir.standardizedFileURL == monitorService.rawStagingDirectoryURL().standardizedFileURL
            guard let urls = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls {
                let stdPath = url.standardizedFileURL.path
                guard !seenPaths.contains(stdPath) else { continue }
                let filename = url.lastPathComponent
                let matches = isStaging
                    ? (filename.lowercased().hasSuffix(".png") || filename.lowercased().hasSuffix(".jpg"))
                    : ScreenshotMonitorService.isScreenshotFilename(filename)
                guard matches,
                      let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let modDate = values.contentModificationDate else { continue }
                seenPaths.insert(stdPath)
                candidateFiles.append((url, modDate))
            }
        }

        candidateFiles.sort { $0.date > $1.date }
        var loaded: [ScreenshotModel] = []
        for entry in candidateFiles.prefix(16) {
            guard let image = NSImage(contentsOf: entry.url), image.size.width > 16 else { continue }
            let model = ScreenshotModel(
                image: image,
                fileURL: entry.url,
                tempFileURL: entry.url,
                targetDestinationURL: entry.url,
                fileName: entry.url.lastPathComponent,
                recognizedText: "",
                isRecognizing: false,
                timestamp: entry.date
            )
            loaded.append(model)
        }
        if !loaded.isEmpty {
            self.history = loaded
            self.selectedHistoryItemID = loaded.first?.id
        }
    }

    func copyScreenshot(_ item: ScreenshotModel) {
        monitorService.suppressMonitoring(for: 2.0)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiffData = item.image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    func revealInFinder(_ item: ScreenshotModel) {
        if let url = existingURL(for: item) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func openInPreview(_ item: ScreenshotModel) {
        if let url = existingURL(for: item) {
            NSWorkspace.shared.open(url)
            centerPreviewWindowOnScreen()
        }
    }

    func deleteFromHistory(_ item: ScreenshotModel) {
        if let tempURL = item.tempFileURL, fileManager.fileExists(atPath: tempURL.path) {
            try? fileManager.removeItem(at: tempURL)
        }
        if let targetURL = item.targetDestinationURL, fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        history.removeAll { $0.id == item.id }
        if selectedHistoryItemID == item.id {
            selectedHistoryItemID = history.first?.id
        }
    }

    func clearHistory() {
        history.removeAll()
        selectedHistoryItemID = nil
    }

    func existingURL(for item: ScreenshotModel) -> URL? {
        if let target = item.targetDestinationURL, fileManager.fileExists(atPath: target.path) {
            return target
        }
        if let fileURL = item.fileURL, fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        if let tempURL = item.tempFileURL, fileManager.fileExists(atPath: tempURL.path) {
            return tempURL
        }
        return getFileURL(for: item)
    }

    func captureInteractiveScreenshot() {
        let stagingDir = monitorService.rawStagingDirectoryURL()
        try? fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let fileName = "Screenshot \(formatter.string(from: Date())).png"
        let outputURL = stagingDir.appendingPathComponent(fileName)
        monitorService.markPathAsKnown(outputURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", outputURL.path]
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.fileManager.fileExists(atPath: outputURL.path),
                      let image = NSImage(contentsOf: outputURL) else { return }
                self.processNewScreenshot(image: image, fileURL: outputURL, fileName: fileName)
            }
        }
        try? process.run()
    }

    func triggerDemoFlyToNotch() {
        let stagingDir = monitorService.rawStagingDirectoryURL()
        try? fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let fileName = "Screenshot \(formatter.string(from: Date())).png"
        let outputURL = stagingDir.appendingPathComponent(fileName)
        monitorService.markPathAsKnown(outputURL.path)

        let capturedImage: NSImage
        if let cgImage = CGDisplayCreateImage(CGMainDisplayID()) {
            capturedImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2))
        } else {
            capturedImage = Self.makePreviewCardImage(title: fileName)
        }
        writePNG(image: capturedImage, to: outputURL)
        processNewScreenshot(image: capturedImage, fileURL: outputURL, fileName: fileName)
    }

    private static func makePreviewCardImage(title: String) -> NSImage {
        let size = NSSize(width: 640, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.22, alpha: 1.0),
            NSColor(calibratedRed: 0.14, green: 0.34, blue: 0.42, alpha: 1.0)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 35)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        ("Notchie Capture\n" + title as NSString).draw(in: NSRect(x: 36, y: 160, width: 560, height: 120), withAttributes: attrs)
        image.unlockFocus()
        return image
    }
    
    func markAsDropped() {
        isDropped = true
    }
    
    func copyImageToClipboard() {
        guard let image = activeScreenshot?.image else { return }
        isCopied = true
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        dismiss()
    }
    
    func showInFinder() {
        saveToDiskIfNeeded()
        guard let targetURL = activeScreenshot?.targetDestinationURL,
              fileManager.fileExists(atPath: targetURL.path) else { return }
        
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        if let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            finderApp.activate()
        }
        dismiss()
    }
    
    func openEditingWindow() {
        saveToDiskIfNeeded()
        guard let targetURL = activeScreenshot?.targetDestinationURL,
              fileManager.fileExists(atPath: targetURL.path) else { return }
        
        NSWorkspace.shared.open(targetURL)
        centerPreviewWindowOnScreen()
        dismiss()
    }
    
    private func centerPreviewWindowOnScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let script = """
            tell application "System Events"
                repeat with appName in {"Preview", "Просмотр", "QuickLook"}
                    if exists (process appName) then
                        tell process appName
                            if (count of windows) > 0 then
                                set win to window 1
                                set {w, h} to size of win
                                tell application "Finder"
                                    set screenBounds to bounds of window of desktop
                                    set screenW to item 3 of screenBounds
                                    set screenH to item 4 of screenBounds
                                end tell
                                set newX to (screenW - w) / 2
                                set newY to (screenH - h) / 2
                                set position of win to {newX, newY}
                                exit repeat
                            end if
                        end tell
                    end if
                end repeat
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
        
        if let panel = QLPreviewPanel.shared(), QLPreviewPanel.sharedPreviewPanelExists() {
            panel.center()
        }
    }
    
    func makeItemProvider(for screenshot: ScreenshotModel) -> NSItemProvider {
        if let url = getFileURL(for: screenshot) {
            let provider = NSItemProvider(object: url as NSURL)
            provider.registerObject(screenshot.image, visibility: .all)
            return provider
        } else {
            return NSItemProvider(object: screenshot.image)
        }
    }
    
    func makePasteboardWriter(for screenshot: ScreenshotModel) -> NSPasteboardWriting {
        if let url = getFileURL(for: screenshot) {
            return url as NSURL
        } else {
            return screenshot.image
        }
    }
    
    private func getFileURL(for screenshot: ScreenshotModel) -> URL? {
        if let tempURL = screenshot.tempFileURL, fileManager.fileExists(atPath: tempURL.path) {
            return tempURL
        }
        if let fileURL = screenshot.fileURL, fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        let tempDir = fileManager.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("Screenshot_\(Int(Date().timeIntervalSince1970)).png")
        writePNG(image: screenshot.image, to: tempURL)
        return tempURL
    }
    
    func deleteScreenshot() {
        isDeleted = true
        if let activeID = activeScreenshot?.id {
            history.removeAll { $0.id == activeID }
        }
        if let tempURL = activeScreenshot?.tempFileURL {
            try? fileManager.removeItem(at: tempURL)
        }
        if let targetURL = activeScreenshot?.targetDestinationURL, fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        dismiss()
    }
    
    func dismiss() {
        onScreenshotDismissed?()
        
        saveToDiskIfNeeded()
        
        if isDropped || isDeleted || isCopied {
            if let tempURL = activeScreenshot?.tempFileURL {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    try? self?.fileManager.removeItem(at: tempURL)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.activeScreenshot = nil
        }
    }
    
    func saveToDiskIfNeeded() {
        guard !isSavedToDisk, !isDeleted, !isDropped, !isCopied else { return }
        guard let screenshot = activeScreenshot else { return }
        
        let targetDir = monitorService.userTargetDirectoryURL
        let targetURL = screenshot.targetDestinationURL ?? targetDir.appendingPathComponent("Screenshot_\(Int(Date().timeIntervalSince1970)).png")
        
        let finalTargetURL = uniqueURL(for: targetURL)
        monitorService.markPathAsKnown(finalTargetURL.path)
        
        isSavedToDisk = true
        if var current = activeScreenshot {
            current.targetDestinationURL = finalTargetURL
            self.activeScreenshot = current
            if let idx = history.firstIndex(where: { $0.id == current.id }) {
                history[idx].targetDestinationURL = finalTargetURL
            }
        }
        
        if let tempURL = screenshot.tempFileURL, fileManager.fileExists(atPath: tempURL.path) {
            do {
                try fileManager.moveItem(at: tempURL, to: finalTargetURL)
                return
            } catch {
                writePNG(image: screenshot.image, to: finalTargetURL)
                try? fileManager.removeItem(at: tempURL)
                return
            }
        }
        
        writePNG(image: screenshot.image, to: finalTargetURL)
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
    
    private func writePNG(image: NSImage, to url: URL) {
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
    }
    
    private func defaultScreenshotDirectory() -> URL {
        if let customLocation = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let expanded = (customLocation as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    }
    
    private func setupMonitoring() {
        monitorService.onScreenshotCaptured = { [weak self] image, fileURL, fileName in
            self?.processNewScreenshot(image: image, fileURL: fileURL, fileName: fileName)
        }
    }
}
