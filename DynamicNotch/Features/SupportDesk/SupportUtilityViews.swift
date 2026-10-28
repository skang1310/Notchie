import SwiftUI
internal import AppKit
import UniformTypeIdentifiers

struct CalculatorToolView: View {
    @State private var input = ""
    @State private var answer = ""
    @State private var from = "ms"
    @State private var to = "s"
    private var units: [String] { LocalCalculator.units.keys.sorted() + ["°C", "°F", "K"] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("support.calc.expression", text: $input).textFieldStyle(.roundedBorder).onSubmit { calculate() }
            HStack { Button("support.calc.evaluate") { calculate() }; Spacer(); Text("+ − × ÷ ( ) %").font(.caption) }
            HStack {
                Picker("support.calc.from", selection: $from) { ForEach(units, id: \.self) { Text($0).tag($0) } }
                Picker("support.calc.to", selection: $to) { ForEach(units, id: \.self) { Text($0).tag($0) } }
                Button("support.calc.convert") { perform { try LocalCalculator.convert(LocalCalculator.evaluate(input), from: from, to: to) } }
            }
            Text(answer).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
            Text("support.calc.local").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }
    private func calculate() { perform { try LocalCalculator.evaluate(input) } }
    private func perform(_ operation: () throws -> Double) { do { answer = String(format: "%.12g", try operation()) } catch { answer = error.localizedDescription } }
}
struct DeveloperTextToolsView: View {
    @State private var left = ""
    @State private var right = ""
    @State private var output = ""
    @State private var operation = "json"
    @State private var busy = false
    private let choices = ["json", "minify", "diff", "url", "redact", "singular"]
    var body: some View {
        VStack(spacing: 10) {
            Picker("support.text.operation", selection: $operation) { ForEach(choices, id: \.self) { Text(L10n.app("support.text.\($0)")).tag($0) } }
            TextEditor(text: $left).font(.system(size: 11, design: .monospaced)).frame(minHeight: 65, maxHeight: 120).border(.secondary.opacity(0.2)).accessibilityLabel("support.text.input")
            if operation == "diff" { TextEditor(text: $right).font(.system(size: 11, design: .monospaced)).frame(height: 65).border(.secondary.opacity(0.2)).accessibilityLabel("support.text.compare") }
            HStack {
                Button("support.text.run") { run() }.disabled(busy)
                Button("productivity.copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string) }.disabled(output.isEmpty)
                if busy { ProgressView().controlSize(.small) }
            }
            ScrollView { Text(output).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 50, maxHeight: 150)
            Text("support.text.local").font(.caption).foregroundStyle(.secondary)
            if operation == "singular" {
                Link("support.text.reference", destination: URL(string: "https://support.singular.net/hc/en-us/articles/31496864868635-Server-to-Server-EVENT-Endpoint-API-Reference")!)
            }
        }.padding()
    }
    private func run() {
        guard !busy else { return }; busy = true
        let a = left, b = right, op = operation
        Task {
            let result = await Task.detached { () -> String in
                do {
                    switch op {
                    case "minify": return try SupportTextTools.json(a, compact: true)
                    case "diff": return try SupportTextTools.diff(a, b)
                    case "url": return try SupportTextTools.decodedQuery(a)
                    case "redact": return try SupportTextTools.redacted(a)
                    case "singular": return try SupportTextTools.singularSummary(a)
                    default: return try SupportTextTools.json(a)
                    }
                } catch { return error.localizedDescription }
            }.value
            output = result; busy = false
        }
    }
}
struct ShortcutsToolView: View {
    @StateObject private var runner = LocalJobRunner()
    @State private var names: [String] = []
    @State private var selected = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("support.shortcuts.description").font(.caption).foregroundStyle(.secondary)
            Button("support.shortcuts.list") {
                runner.run(executable: URL(fileURLWithPath: "/usr/bin/shortcuts"), arguments: ["list"], announcesCompletion: false) { code in
                    guard code == 0 else { return }
                    names = runner.output.split(whereSeparator: \.isNewline).map(String.init)
                    selected = names.first ?? ""
                }
            }.disabled(runner.isRunning)
            Picker("support.shortcuts.choose", selection: $selected) { Text("—").tag(""); ForEach(names, id: \.self) { Text($0).tag($0) } }
            Button("support.shortcuts.run") { runner.run(executable: URL(fileURLWithPath: "/usr/bin/shortcuts"), arguments: ["run", selected], announcesCompletion: false) }.disabled(selected.isEmpty || runner.isRunning)
            UtilityJobStatus(runner: runner)
        }.padding()
    }
}
struct UtilityJobStatus: View {
    @ObservedObject var runner: LocalJobRunner
    var body: some View {
        VStack(alignment: .leading) {
            if runner.isRunning { HStack { ProgressView().controlSize(.small); Button("productivity.jobs.cancel") { runner.cancel() } } }
            else if case .completed(let code) = runner.state { Text("exit \(code) · \(Int(runner.seconds))s").font(.caption) }
            else if case .failed(let reason) = runner.state { Text(reason).foregroundStyle(.red).font(.caption) }
            ScrollView { Text(runner.output).font(.system(size: 10, design: .monospaced)).textSelection(.enabled) }.frame(maxHeight: 90)
        }
    }
}
struct ZipToolView: View {
    @StateObject private var runner = LocalJobRunner()
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("support.zip.description").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("support.zip.create") { create() }.disabled(runner.isRunning)
                Button("support.zip.extract") { extract() }.disabled(runner.isRunning)
            }
            Text(message).font(.caption).textSelection(.enabled)
            UtilityJobStatus(runner: runner)
        }.padding()
    }
    private func create() {
        let picker = NSOpenPanel(); picker.allowsMultipleSelection = true; picker.canChooseDirectories = false
        guard picker.runModal() == .OK, !picker.urls.isEmpty else { return }
        let files = picker.urls
        guard Set(files.map { $0.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased() }).count == files.count else { message = SupportToolError.duplicateNames.localizedDescription; return }
        guard files.allSatisfy({ (try? $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])).map { $0.isRegularFile == true && $0.isSymbolicLink != true } ?? false }) else { message = SupportToolError.unsafeArchive.localizedDescription; return }
        let save = NSSavePanel(); save.allowedContentTypes = [.zip]; save.nameFieldStringValue = "Evidence.zip"
        guard save.runModal() == .OK, let target = save.url, !FileManager.default.fileExists(atPath: target.path) else { return }
        runner.run(executable: URL(fileURLWithPath: "/usr/bin/zip"), arguments: ["-j", "-X", target.path, "--"] + files.map(\.path), announcesCompletion: false) { code in
            message = code == 0 ? target.path : L10n.app("productivity.jobs.failure")
        }
    }
    private func extract() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.zip]
        guard picker.runModal() == .OK, let source = picker.url else { return }
        Task { do {
            let (archiveData, report) = try await Task.detached {
                let access = source.startAccessingSecurityScopedResource()
                defer { if access { source.stopAccessingSecurityScopedResource() } }
                let bytes = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard bytes <= 256 * 1024 * 1024 else { throw SupportToolError.limit }
                let data = try Data(contentsOf: source)
                return (data, try ZipInspection(data: data))
            }.value
            let destination = NSOpenPanel(); destination.canChooseDirectories = true; destination.canChooseFiles = false
            guard destination.runModal() == .OK, let parent = destination.url else { return }
            let target = parent.appendingPathComponent(source.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString.prefix(6))
            let staging = parent.appendingPathComponent(".DynamicNotch-extract-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let archiveCopy = FileManager.default.temporaryDirectory.appendingPathComponent("DynamicNotch-" + UUID().uuidString + ".zip")
            do { try archiveData.write(to: archiveCopy, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: archiveCopy.path) }
            catch { try? FileManager.default.removeItem(at: staging); try? FileManager.default.removeItem(at: archiveCopy); throw error }
            runner.run(executable: URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-x", "-k", archiveCopy.path, staging.path], announcesCompletion: false) { code in
                defer { try? FileManager.default.removeItem(at: archiveCopy) }
                do {
                    guard code == 0 else { throw SupportToolError.invalid }
                    try FileManager.default.moveItem(at: staging, to: target)
                    message = "\(report.names.count) · \(target.path)"
                } catch { try? FileManager.default.removeItem(at: staging); message = error.localizedDescription }
            }
        } catch { message = error.localizedDescription } }
    }
}
