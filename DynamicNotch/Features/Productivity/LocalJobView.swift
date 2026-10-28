import SwiftUI
internal import AppKit
import UniformTypeIdentifiers

struct LocalJobView: View {
    @ObservedObject var runner: LocalJobRunner
    @State private var project: URL?
    @State private var scheme = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("productivity.jobs.description").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("productivity.jobs.project") {
                    let picker = NSOpenPanel(); picker.canChooseFiles = true; picker.canChooseDirectories = false
                    picker.allowedContentTypes = [UTType(filenameExtension: "xcodeproj"), UTType(filenameExtension: "xcworkspace")].compactMap { $0 }; picker.treatsFilePackagesAsDirectories = false
                    if picker.runModal() == .OK { project = picker.url }
                }.disabled(runner.isRunning)
                Text(project?.lastPathComponent ?? "—").font(.caption).lineLimit(1)
            }
            HStack {
                TextField("productivity.jobs.scheme", text: $scheme).textFieldStyle(.roundedBorder)
                Button("productivity.jobs.build") {
                    guard let project else { return }
                    let flag = project.pathExtension == "xcworkspace" ? "-workspace" : "-project"
                    let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DynamicNotch/TaskBuilds").path
                    runner.run(executable: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: [flag, project.path, "-scheme", scheme.trimmingCharacters(in: .whitespacesAndNewlines), "-configuration", "Debug", "-derivedDataPath", path, "CODE_SIGNING_ALLOWED=NO", "build"])
                }.disabled(project == nil || scheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || runner.isRunning)
            }
            Button("productivity.jobs.hash") {
                let picker = NSOpenPanel(); picker.canChooseDirectories = false
                if picker.runModal() == .OK, let url = picker.url {
                    runner.run(executable: URL(fileURLWithPath: "/usr/bin/shasum"), arguments: ["-a", "256", "--", url.path])
                }
            }.disabled(runner.isRunning)
            HStack {
                Text(status).font(.caption).textSelection(.enabled)
                Spacer()
                if runner.isRunning { Button("productivity.jobs.cancel") { runner.cancel() } }
            }
            ScrollView { Text(runner.output).font(.system(size: 10, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 70, maxHeight: 140)
        }.padding()
    }
    private var status: String {
        switch runner.state {
        case .idle: return L10n.app("productivity.jobs.ready")
        case .running: return L10n.app("productivity.jobs.running")
        case .completed(let code): return "\(L10n.app(code == 0 ? "productivity.jobs.success" : "productivity.jobs.failure")) · exit \(code) · \(Int(runner.seconds))s"
        case .cancelled(let code): return "\(L10n.app("productivity.jobs.cancelled")) · exit \(code)"
        case .failed(let error): return error
        }
    }
}
