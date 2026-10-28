import Foundation
import Combine

@MainActor
final class LocalJobRunner: ObservableObject {
    enum State: Equatable { case idle, running, completed(Int32), cancelled(Int32), failed(String) }
    @Published private(set) var state: State = .idle
    @Published private(set) var output = ""
    @Published private(set) var seconds: TimeInterval = 0
    private var process: Process?
    private var started: ContinuousClock.Instant?
    private var cancellationRequested = false
    private var retainedPipe: Pipe?
    private var completion: ((Int32) -> Void)?
    private var terminationCode: Int32?
    private var outputEnded = false
    private var announcesCompletion = true
    var isRunning: Bool { state == .running }
    /// No shell interpreter or free-form command string. Arguments passed directly.
    func run(executable: URL, arguments: [String], announcesCompletion: Bool = true, completion: ((Int32) -> Void)? = nil) {
        guard !isRunning else { return }
        let allowed = ["/usr/bin/xcodebuild", "/usr/bin/shasum", "/usr/bin/shortcuts", "/usr/bin/zip", "/usr/bin/ditto"]
        guard allowed.contains(executable.path) else { state = .failed("Unsupported executable"); return }
        self.completion = completion; self.announcesCompletion = announcesCompletion
        terminationCode = nil; outputEnded = false
        let p = Process(), pipe = Pipe()
        p.executableURL = executable; p.arguments = arguments
        p.standardOutput = pipe; p.standardError = pipe
        output = ""; seconds = 0; started = .now; cancellationRequested = false
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                Task { @MainActor [weak self] in self?.outputEnded = true; self?.finishWhenDrained() }
                return
            }
            let chunk = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.append(chunk) }
        }
        p.terminationHandler = { [weak self] process in
            let code = process.terminationStatus
            Task { @MainActor [weak self] in self?.terminationCode = code; self?.finishWhenDrained() }
        }
        do { try p.run(); process = p; retainedPipe = pipe; state = .running; try? pipe.fileHandleForWriting.close() }
        catch { pipe.fileHandleForReading.readabilityHandler = nil; state = .failed(error.localizedDescription); process = nil; retainedPipe = nil; let callback = self.completion; self.completion = nil; callback?(-1) }
    }
    private func append(_ chunk: String) { output = String(decoding: Data((output + chunk).utf8).suffix(64_000), as: UTF8.self) }
    private func finishWhenDrained() { if outputEnded, let code = terminationCode { terminationCode = nil; finished(code: code) } }
    private func finished(code: Int32) {
        seconds = started.map { Double($0.duration(to: .now).components.seconds) } ?? 0
        state = cancellationRequested ? .cancelled(code) : .completed(code)
        process = nil; retainedPipe = nil
        let callback = completion; completion = nil
        callback?(code)
        if announcesCompletion { NotificationCenter.default.post(name: .localJobCompleted, object: nil) }
    }
    func cancel() { guard let process, process.isRunning else { return }; cancellationRequested = true; process.interrupt() }
    func shutdown() { if let process, process.isRunning { cancellationRequested = true; process.terminate() } }
}
extension Notification.Name { static let localJobCompleted = Notification.Name("DynamicNotch.LocalJobCompleted") }
