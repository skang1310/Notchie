import Foundation
import CoreGraphics
import ImageIO
import CoreImage
import UniformTypeIdentifiers
internal import Vision
internal import AppKit

nonisolated enum ShelfTransform {
    static let maxFileBytes = 30 * 1024 * 1024
    static func boundedImage(_ url: URL) throws -> CGImage {
        guard url.isFileURL,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxFileBytes,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
    static func combinedPDF(_ urls: [URL]) throws -> Data {
        guard !urls.isEmpty, urls.count <= 20 else { throw CocoaError(.fileReadTooLarge) }
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { throw CocoaError(.fileWriteUnknown) }
        var pageCount = 0
        for url in urls {
            guard url.isFileURL, let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxFileBytes else { throw CocoaError(.fileReadTooLarge) }
            if url.pathExtension.lowercased() == "pdf" {
                guard let document = CGPDFDocument(url as CFURL), !document.isEncrypted, document.numberOfPages > 0,
                      pageCount + document.numberOfPages <= 200 else { throw CocoaError(.fileReadCorruptFile) }
                for index in 1...document.numberOfPages {
                    guard let page = document.page(at: index) else { throw CocoaError(.fileReadCorruptFile) }
                    let sourceBounds = page.getBoxRect(.mediaBox)
                    guard sourceBounds.width.isFinite, sourceBounds.height.isFinite, sourceBounds.width > 0, sourceBounds.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
                    let rotated = abs(page.rotationAngle % 180) == 90
                    let rect = CGRect(x: 0, y: 0, width: rotated ? sourceBounds.height : sourceBounds.width, height: rotated ? sourceBounds.width : sourceBounds.height)
                    var pageRect = rect
                    let boxData = Data(bytes: &pageRect, count: MemoryLayout<CGRect>.size)
                    context.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
                    context.saveGState()
                    context.concatenate(page.getDrawingTransform(.mediaBox, rect: rect, rotate: 0, preserveAspectRatio: true))
                    context.drawPDFPage(page)
                    context.restoreGState(); context.endPDFPage(); pageCount += 1
                }
            } else {
                let image = try boundedImage(url)
                var rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                let boxData = Data(bytes: &rect, count: MemoryLayout<CGRect>.size)
                context.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
                context.draw(image, in: rect); context.endPDFPage(); pageCount += 1
            }
        }
        context.closePDF()
        return data as Data
    }
    static func removeBackground(_ url: URL) throws -> Data {
        let image = try boundedImage(url)
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else { throw CocoaError(.fileReadUnknown) }
        let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let output = CIContext().createCGImage(ciImage, from: ciImage.extent) else { throw CocoaError(.fileWriteUnknown) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
}

private extension NSValue {
    var dataForPDFBox: Data {
        var rect = rectValue
        return Data(bytes: &rect, count: MemoryLayout<CGRect>.size)
    }
}
