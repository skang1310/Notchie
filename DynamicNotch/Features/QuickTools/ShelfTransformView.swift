import SwiftUI
internal import AppKit
import UniformTypeIdentifiers

struct ShelfTransformView: View {
    @State private var files: [URL] = []
    @State private var busy = false
    @State private var message = ""
    @State private var recognizedText = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(privacyText("Transform", "파일 변환"), systemImage: "wand.and.stars").font(.caption.weight(.semibold))
                Spacer()
                Button(privacyText("Choose files…", "파일 선택…")) { pickFiles() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(files.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Text("\(index + 1). \(url.lastPathComponent)").lineLimit(1).font(.caption)
                            Spacer()
                            Button { files.swapAt(index, index - 1) } label: { Image(systemName: "chevron.up") }.disabled(index == 0)
                            Button { files.remove(at: index) } label: { Image(systemName: "minus.circle") }
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: 64)
            HStack {
                Button(privacyText("Combine PDF…", "PDF로 합치기…")) { transform(background: false) }.disabled(files.isEmpty)
                Button(privacyText("Remove background…", "배경 제거…")) { transform(background: true) }.disabled(files.count != 1 || files.first?.pathExtension.lowercased() == "pdf")
                Button(privacyText("Extract text", "텍스트 추출")) { recognize() }.disabled(files.count != 1 || files.first?.pathExtension.lowercased() == "pdf")
                if busy { ProgressView().controlSize(.small) }
            }.controlSize(.small)
            if !recognizedText.isEmpty {
                HStack {
                    Text(recognizedText).font(.caption).lineLimit(2).textSelection(.enabled)
                    Spacer()
                    Button(privacyText("Copy", "복사")) {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(recognizedText, forType: .string)
                    }.controlSize(.small)
                }
            }
            Text(message.isEmpty ? privacyText("On-device processing · Originals preserved · Up to 20 files, 30 MB each. Images up to 4096 px; PDFs up to 200 pages. Reorder files above before combining.", "기기 내 처리 · 원본 보존 · 최대 20개, 파일당 30 MB. 이미지는 최대 4096px, PDF는 최대 200페이지. 위에서 순서를 조정할 수 있습니다.") : message)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(3)
        }.padding(8).disabled(busy)
    }
    private func pickFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.allowedContentTypes = [.image, .pdf]
        guard panel.runModal() == .OK else { return }
        guard panel.urls.count <= 20 else { message = privacyText("Choose up to 20 files.", "파일은 최대 20개까지 선택하세요."); return }
        files = panel.urls; message = ""; recognizedText = ""
    }
    private func transform(background: Bool) {
        let inputs = files
        let panel = NSSavePanel(); panel.allowedContentTypes = background ? [.png] : [.pdf]
        panel.nameFieldStringValue = background ? "cutout.png" : "combined.pdf"
        guard panel.runModal() == .OK, let target = panel.url else { return }
        guard !inputs.contains(where: { $0.resolvingSymlinksInPath().standardizedFileURL == target.resolvingSymlinksInPath().standardizedFileURL }) else {
            message = privacyText("Choose a different name to preserve the original.", "원본을 보존하도록 다른 이름을 선택하세요."); return
        }
        busy = true
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    if background { return try ShelfTransform.removeBackground(inputs[0]) }
                    return try ShelfTransform.combinedPDF(inputs)
                }.value
                try data.write(to: target, options: .atomic)
                message = privacyText("Saved: ", "저장됨: ") + target.lastPathComponent
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
    private func recognize() {
        guard let file = files.first else { return }
        busy = true
        Task {
            do {
                let cgImage = try await Task.detached(priority: .userInitiated) { try ShelfTransform.boundedImage(file) }.value
                recognizedText = await OCRService.shared.recognizeText(in: NSImage(cgImage: cgImage, size: .zero), languages: ["ko-KR", "en-US"])
                message = recognizedText.isEmpty ? privacyText("No readable text found.", "인식할 수 있는 텍스트가 없습니다.") : privacyText("Text recognized locally.", "기기에서 텍스트를 추출했습니다.")
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}
