import Foundation
import CryptoKit
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

nonisolated struct SupportRedaction: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var x: Double; var y: Double; var width: Double; var height: Double
    var valid: Bool { [x,y,width,height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0 && x+width <= 1.000001 && y+height <= 1.000001 }
}
nonisolated struct SupportScreenshot: Codable, Identifiable, Sendable {
    var id = UUID()
    var file: String
    var digest: String
    var capturedAt: Date
    var width: Int; var height: Int
    var caption = ""
    var ocr = ""
    var redactions: [SupportRedaction] = []
}
nonisolated struct SupportCase: Codable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var ticket = ""
    var app = ""
    var platform = "iOS"
    var sdkVersion = ""
    var timeZone = TimeZone.current.identifier
    var reportAContext = ""
    var reportBContext = ""
    var expected = ""
    var actual = ""
    var notes = ""
    var createdAt = Date()
    var screenshots: [SupportScreenshot] = []
}
nonisolated struct SupportCasesDocument: Codable, Sendable { var version = 1; var cases: [SupportCase] = [] }
nonisolated enum SupportImages {
    struct Loaded: Sendable { let bytes: Data; let digest: String; let width: Int; let height: Int; let date: Date; let suffix: String }
    static func load(_ url: URL) throws -> Loaded {
        let scope = url.startAccessingSecurityScopedResource(); defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let info = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, let size = info.fileSize, size > 0, size <= 50 * 1024 * 1024 else { throw SupportToolError.limit }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= 50 * 1024 * 1024, let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0, w <= 20_000, h <= 20_000, w * h <= 36_000_000 else { throw SupportToolError.limit }
        let rotated = (5...8).contains(props[kCGImagePropertyOrientation] as? Int ?? 1)
        let type = CGImageSourceGetType(source).map { $0 as String } ?? UTType.png.identifier
        let suffix = UTType(type)?.preferredFilenameExtension ?? "image"
        return Loaded(bytes: bytes, digest: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), width: rotated ? h : w, height: rotated ? w : h, date: info.contentModificationDate ?? .now, suffix: suffix)
    }
    static func png(url: URL, maxPixel: Int, redactions: [SupportRedaction] = []) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true, kCGImageSourceCreateThumbnailWithTransform:true, kCGImageSourceThumbnailMaxPixelSize:maxPixel] as CFDictionary),
              let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw SupportToolError.invalid }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.setShouldAntialias(false)
        for r in redactions {
            guard r.valid else { throw SupportToolError.invalid }
            let rect = CGRect(x: r.x * Double(image.width), y: (1-r.y-r.height) * Double(image.height), width: r.width * Double(image.width), height: r.height * Double(image.height)).integral
            ctx.fill(rect)
        }
        let out = NSMutableData()
        guard let rendered = ctx.makeImage(), let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { throw SupportToolError.invalid }
        CGImageDestinationAddImage(dest, rendered, nil)
        guard CGImageDestinationFinalize(dest) else { throw SupportToolError.invalid }
        return out as Data
    }
    static func markdown(_ item: SupportCase) -> String {
        func clean(_ s: String) -> String { (try? SupportTextTools.redacted(s)) ?? "<omitted>" }
        let captions = item.screenshots.enumerated().map { index, shot in
            "### \(index+1). \(clean(shot.caption))\n\n![Evidence \(index+1)](images/\(index+1).png)\n\nCaptured: \(ISO8601DateFormatter().string(from: shot.capturedAt))\n"
        }.joined(separator: "\n")
        return """
        # \(clean(item.title))

        Ticket: \(clean(item.ticket))
        App: \(clean(item.app))
        Platform: \(clean(item.platform))
        SDK: \(clean(item.sdkVersion))
        Time zone: \(clean(item.timeZone))

        ## Report A settings
        \(clean(item.reportAContext))

        ## Report B settings
        \(clean(item.reportBContext))

        ## Expected
        \(clean(item.expected))

        ## Observed
        \(clean(item.actual))

        ## Notes
        \(clean(item.notes))

        ## Evidence
        \(captions)

        Export uses flattened image redactions. OCR text and original image metadata are excluded. Review the evidence before sending; text masking only detects known patterns.
        """
    }
}
