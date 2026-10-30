import Foundation
import Darwin

/// Read-only local app-server transport. Never creates threads, runs turns or changes authentication.
@MainActor
final class CodexLiveQuotaClient {
    static let shared = CodexLiveQuotaClient()
    private var consumers = Set<UUID>()
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var serial = 0
    private var epoch = 0
    private var pending: [Int: CheckedContinuation<[String: Any]?, Never>] = [:]
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var startup: Task<Bool, Never>?
    private var initialized = false
    private var cached: RecordedAIQuota?
    private var query: Task<RecordedAIQuota?, Never>?
    private let executableOverride: URL?
    init(executable: URL? = nil) { executableOverride = executable }
    var isRunning: Bool { process?.isRunning == true }
    var consumerCount: Int { consumers.count }
    func acquire(_ id: UUID) { consumers.insert(id) }
    func release(_ id: UUID) {
        consumers.remove(id)
        if consumers.isEmpty { stop() }
    }
    func read() async -> RecordedAIQuota? {
        guard !consumers.isEmpty else { return nil }
        if let cached, Date().timeIntervalSince(cached.recordedAt) < 10 { return cached }
        if let query { return await query.value }
        let generation = epoch
        let work = Task { @MainActor [weak self] () -> RecordedAIQuota? in
            guard let self, await self.start(), !Task.isCancelled, !self.consumers.isEmpty else { return nil }
            guard let response = await self.request("account/rateLimits/read"), !Task.isCancelled,
                  let quota = Self.parse(response, now: .now), generation == self.epoch else { return nil }
            self.cached = quota
            return quota
        }
        query = work
        let value = await work.value
        if generation == epoch { query = nil }
        return value
    }
    private func executable() -> URL? {
        if let executableOverride { return executableOverride }
        let arch = "aarch64-apple-darwin"
        let paths = ["/usr/local/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/\(arch)/codex/codex",
            "/opt/homebrew/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/\(arch)/codex/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }
    private func start() async -> Bool {
        if initialized, isRunning { return true }
        if let startup { return await startup.value }
        let generation = epoch
        let work = Task { @MainActor [weak self] () -> Bool in
            guard let self, let executable = self.executable(), !self.consumers.isEmpty else { return false }
            self.closeTransport()
            let process = Process(), incoming = Pipe(), outgoing = Pipe()
            process.executableURL = executable; process.arguments = ["app-server"]
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment
            process.standardInput = incoming; process.standardOutput = outgoing; process.standardError = FileHandle.nullDevice
            self.process = process; self.input = incoming.fileHandleForWriting; self.output = outgoing.fileHandleForReading
            outgoing.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                Task { @MainActor [weak self] in
                    guard let self, self.process === process else { return }
                    if data.isEmpty { self.closeTransport() } else { self.receive(data) }
                }
            }
            process.terminationHandler = { [weak self] ended in
                Task { @MainActor [weak self] in if self?.process === ended { self?.closeTransport() } }
            }
            do { try process.run() } catch { self.closeTransport(); return false }
            guard await self.request("initialize", params: ["clientInfo": ["name": "notchie_usage", "title": "Notchie Usage", "version": "1.0.0"]]) != nil,
                  !Task.isCancelled, !self.consumers.isEmpty, self.process === process, generation == self.epoch else {
                if self.process === process { self.closeTransport() }; return false
            }
            self.send(["method": "initialized", "params": [:]])
            self.initialized = true
            return true
        }
        startup = work
        let success = await work.value
        if generation == epoch { startup = nil }
        return success
    }
    private func request(_ method: String, params: [String: Any]? = nil) async -> [String: Any]? {
        guard ["initialize", "account/rateLimits/read"].contains(method), isRunning else { return nil }
        serial += 1; let id = serial
        return await withCheckedContinuation { continuation in
            pending[id] = continuation
            deadlines[id] = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(8)) } catch { return }
                self?.complete(id, value: nil)
            }
            var message: [String: Any] = ["id": id, "method": method]
            if let params { message["params"] = params }
            if !send(message) { complete(id, value: nil) }
        }
    }
    @discardableResult private func send(_ message: [String: Any]) -> Bool {
        guard let input, var data = try? JSONSerialization.data(withJSONObject: message) else { return false }
        data.append(10)
        do { try input.write(contentsOf: data); return true } catch { return false }
    }
    private func receive(_ data: Data) {
        guard buffer.count + data.count <= 2 * 1024 * 1024 else { closeTransport(); return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = message["id"] as? Int else { continue }
            complete(id, value: message["result"] as? [String: Any])
        }
    }
    private func complete(_ id: Int, value: [String: Any]?) {
        deadlines.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(returning: value)
    }
    private func closeTransport() {
        initialized = false
        let child = process; process = nil
        output?.readabilityHandler = nil; try? input?.close(); try? output?.close()
        input = nil; output = nil; buffer.removeAll()
        if let child, child.isRunning {
            child.terminate()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            }
        }
        for id in Array(pending.keys) { complete(id, value: nil) }
    }
    func stop() {
        epoch += 1
        query?.cancel(); query = nil; startup?.cancel(); startup = nil
        closeTransport()
    }
    static func parse(_ response: [String: Any], now: Date) -> RecordedAIQuota? {
        let multiple = response["rateLimitsByLimitId"] as? [String: [String: Any]]
        guard let limit = multiple?["codex"] ?? response["rateLimits"] as? [String: Any],
              limit["limitId"] == nil || limit["limitId"] is NSNull || limit["limitId"] as? String == "codex" else { return nil }
        func window(_ raw: Any?) -> [String: Any]? {
            guard let json = raw as? [String: Any], let used = json["usedPercent"],
                  let minutes = json["windowDurationMins"], let reset = json["resetsAt"] else { return nil }
            return ["used_percent": used, "window_minutes": minutes, "resets_at": reset]
        }
        guard let primary = window(limit["primary"]) else { return nil }
        var limits: [String: Any] = ["limit_id": "codex", "primary": primary]
        if let secondary = window(limit["secondary"]) { limits["secondary"] = secondary }
        if let plan = limit["planType"] { limits["plan_type"] = plan }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        let envelope: [String: Any] = ["type": "event_msg", "timestamp": formatter.string(from: now),
            "payload": ["type": "token_count", "rate_limits": limits]]
        return (try? JSONSerialization.data(withJSONObject: envelope)).flatMap(RecordedAIQuota.parseCodex)
    }
}
