import SwiftUI
internal import AppKit

@MainActor
final class SupportDeskCoordinator {
    static let shared = SupportDeskCoordinator()
    let store = SupportCaseStore.shared
    let watcher = SupportFolderWatcher()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let w = NSWindow(contentRect:NSRect(x:0,y:0,width:1120,height:740),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            w.title = L10n.app("support.board.title"); w.isReleasedWhenClosed = false; w.minSize = NSSize(width:940,height:620)
            w.contentView = NSHostingView(rootView:SupportBoardView(store:store,watcher:watcher)); w.center(); window = w
        }
        NSApp.activate(ignoringOtherApps:true); window?.makeKeyAndOrderFront(nil)
    }
    func shutdown() { watcher.stop(); window?.orderOut(nil) }
}
@MainActor
final class SupportThumbnailCache {
    static let shared = SupportThumbnailCache()
    private let cache = NSCache<NSString,NSData>()
    init() { cache.countLimit = 100; cache.totalCostLimit = 40 * 1024 * 1024 }
    func data(url:URL,size:Int,redactions:[SupportRedaction]) async -> Data? {
        let key = (url.path + "-\(size)-" + redactions.map(\.id.uuidString).joined()) as NSString
        if let value = cache.object(forKey:key) { return value as Data }
        guard !Task.isCancelled else { return nil }
        let result = try? await SupportImageDecoder.shared.png(url:url,size:size,redactions:redactions)
        if let result { cache.setObject(result as NSData,forKey:key,cost:result.count) }
        return result
    }
}
struct SupportThumbnailView: View {
    let shot: SupportScreenshot
    let url: URL
    var size = 300
    @State private var bytes: Data?
    var body: some View {
        Group {
            if let bytes, let image = NSImage(data:bytes) { Image(nsImage:image).resizable().scaledToFit() }
            else { Image(systemName:"photo").foregroundStyle(.secondary) }
        }.task(id:url.path + "\(size)" + shot.redactions.map(\.id.uuidString).joined()) {
            bytes = await SupportThumbnailCache.shared.data(url:url,size:size,redactions:shot.redactions)
        }
    }
}

private actor SupportImageDecoder {
    static let shared = SupportImageDecoder()
    func png(url: URL, size: Int, redactions: [SupportRedaction]) throws -> Data {
        guard !Task.isCancelled else { throw CancellationError() }
        return try SupportImages.png(url:url,maxPixel:size,redactions:redactions)
    }
}
struct SupportCaseLauncherView: View {
    @ObservedObject private var store = SupportCaseStore.shared
    var body: some View {
        VStack(spacing:12) {
            Text("support.board.title").font(.headline)
            Text(store.current?.title ?? L10n.app("support.case.start")).font(.subheadline)
            if let item=store.current {
                HStack { ForEach(Array(item.screenshots.suffix(4))) { shot in SupportThumbnailView(shot:shot,url:store.file(shot),size:180).frame(width:80,height:65) } }
                Text("\(item.screenshots.count)").font(.title2)
            }
            Button("support.board.open") { SupportDeskCoordinator.shared.show() }
            Text("support.case.local").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }
}
