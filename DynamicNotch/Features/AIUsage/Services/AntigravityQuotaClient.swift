import Foundation
import CoreFoundation

/// Private, read-only local IDE protocol. Never reads Google OAuth credentials or starts the IDE.
actor AntigravityQuotaClient {
    static let shared = AntigravityQuotaClient()
    nonisolated struct Snapshot: Sendable {
        let windows: [AIQuotaWindow]
        let recordedAt: Date
    }
    nonisolated struct Endpoint: Sendable {
        let port: Int
        let csrf: String
        var url: URL { URL(string: "http://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary")! }
    }
    private var cached: Snapshot?
    private var inFlight: Task<Snapshot?, Never>?
    private var lastAttempt = Date.distantPast
    private let session: URLSession
    private let endpoints: [Endpoint]?
    init(configuration: URLSessionConfiguration? = nil, endpoints: [Endpoint]? = nil) {
        self.endpoints = endpoints
        let config = configuration ?? URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 3
        config.connectionProxyDictionary = [:]
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: LocalQuotaRedirectGuard(), delegateQueue: nil)
    }
    func read(now: Date = .now) async -> Snapshot? {
        if let inFlight { return await inFlight.value }
        if now.timeIntervalSince(lastAttempt) < 10 { return cached }
        lastAttempt = now
        let session = session
        let endpoints = endpoints
        let task = Task.detached(priority: .utility) { () -> Snapshot? in
            for endpoint in endpoints ?? Self.discover() {
                var request = URLRequest(url: endpoint.url)
                request.httpMethod = "POST"
                request.httpBody = Data("{}".utf8)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                request.setValue(endpoint.csrf, forHTTPHeaderField: "X-Codeium-Csrf-Token")
                guard let (data, response) = try? await session.data(for: request),
                      let http = response as? HTTPURLResponse, http.statusCode == 200,
                      data.count <= 2 * 1024 * 1024,
                      let snapshot = Self.parse(data, now: .now) else { continue }
                return snapshot
            }
            return nil
        }
        inFlight = task
        let value = await task.value
        if let value { cached = value }
        inFlight = nil
        return value ?? cached // Original timestamp is preserved on failure.
    }
    nonisolated static func parse(_ data: Data, now: Date) -> Snapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = root["response"] as? [String: Any],
              let groups = response["groups"] as? [[String: Any]] else { return nil }
        let formatter = ISO8601DateFormatter()
        var windows: [AIQuotaWindow] = []
        var seen = Set<String>()
        for group in groups.prefix(12) {
            guard let name = group["displayName"] as? String, !name.isEmpty,
                  let buckets = group["buckets"] as? [[String: Any]] else { continue }
            let shortName = name == "Gemini Models" ? "Gemini" : (name == "Claude and GPT models" ? "Claude/GPT" : name.replacingOccurrences(of: "Gemini 4 ", with: ""))
            for bucket in buckets.prefix(4) {
                guard let label = bucket["displayName"] as? String,
                      let number = bucket["remainingFraction"] as? NSNumber,
                      CFGetTypeID(number) != CFBooleanGetTypeID(),
                      number.doubleValue.isFinite, (0...1).contains(number.doubleValue),
                      let stamp = bucket["resetTime"] as? String else { continue }
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let fractional = formatter.date(from: stamp)
                formatter.formatOptions = [.withInternetDateTime]
                guard let reset = fractional ?? formatter.date(from: stamp) else { continue }
                let id = name + ":" + label
                guard seen.insert(id).inserted else { continue }
                let weekly = label.lowercased().contains("weekly")
                let fiveHour = label.lowercased().contains("five hour")
                let en = weekly ? "Weekly" : (fiveHour ? "5h" : label)
                let ko = weekly ? "주간" : (fiveHour ? "5시간" : label)
                windows.append(AIQuotaWindow(id: id, title: "\(shortName) · \(en)", titleKo: "\(shortName) · \(ko)",
                    subtitle: "Antigravity local quota", subtitleKo: "Antigravity 로컬 한도", utilization: (1 - number.doubleValue) * 100, resetsAt: reset))
            }
        }
        guard !windows.isEmpty else { return nil }
        return Snapshot(windows: windows, recordedAt: now)
    }
    nonisolated static func endpoint(command: String, port: Int) -> Endpoint? {
        let path = "/Applications/Antigravity.app/Contents/Resources/bin/language_server"
        guard command.hasPrefix(path + " "), (1...65535).contains(port),
              let range = command.range(of: #"(?:^|\s)--csrf_token\s+([A-Za-z0-9-]{16,128})(?:\s|$)"#, options: .regularExpression) else { return nil }
        let fields = command[range].split(whereSeparator: { $0.isWhitespace })
        guard fields.count == 2 else { return nil }
        return Endpoint(port: port, csrf: String(fields[1]))
    }
    nonisolated private static func discover() -> [Endpoint] {
        let path = "/Applications/Antigravity.app/Contents/Resources/bin/language_server"
        guard let pids = output("/usr/bin/pgrep", ["-f", "^" + path + " "]) else { return [] }
        var result: [Endpoint] = []
        for pid in pids.split(whereSeparator: { $0.isWhitespace }).prefix(3) where Int(pid) != nil {
            guard let command = output("/bin/ps", ["-p", String(pid), "-o", "command="])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let ports = output("/usr/sbin/lsof", ["-nP", "-a", "-p", String(pid), "-iTCP", "-sTCP:LISTEN", "-Fn"]) else { continue }
            for line in ports.split(separator: "\n") where line.hasPrefix("n127.0.0.1:") {
                guard let port = Int(line.dropFirst("n127.0.0.1:".count)), let endpoint = endpoint(command: command, port: port) else { continue }
                result.append(endpoint)
                if result.count == 6 { return result }
            }
        }
        return result
    }
    nonisolated private static func output(_ path: String, _ arguments: [String]) -> String? {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        if process.isRunning { process.terminate(); return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard data.count < 64 * 1024, process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private final class LocalQuotaRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
