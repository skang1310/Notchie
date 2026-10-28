import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
internal import AppKit

nonisolated enum LocalImageConverter {
    enum Format { case png, jpeg
        var type: UTType { self == .png ? .png : .jpeg }
    }
    static func data(from input: Data, format: Format, maxEdge: Int? = nil) throws -> Data {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 30_000, height <= 30_000,
              width * height <= 80_000_000, maxEdge.map({ (16...8192).contains($0) }) ?? true else { throw CocoaError(.fileReadCorruptFile) }
        let edge = min(max(width, height), maxEdge ?? max(width, height))
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: edge]
        guard var image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        if format == .jpeg {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let flattened = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }; image = flattened
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, format.type.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output as Data
    }
    @MainActor static func export(_ source: URL, format: Format, maxEdge: Int? = nil) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + (maxEdge == nil ? "-converted" : "-1600") + (format == .png ? ".png" : ".jpg")
        guard panel.runModal() == .OK, let target = panel.url else { return }
        do {
            guard source.resolvingSymlinksInPath().standardizedFileURL != target.resolvingSymlinksInPath().standardizedFileURL else { throw CocoaError(.fileWriteInvalidFileName) }
            let output = try data(from: Data(contentsOf: source), format: format, maxEdge: maxEdge)
            try output.write(to: target, options: .atomic)
        } catch { NSAlert(error: error).runModal() }
    }
}
