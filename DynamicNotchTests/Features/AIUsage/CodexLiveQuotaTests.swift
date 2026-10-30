import XCTest
@testable import DynamicNotch

@MainActor
final class CodexLiveQuotaTests: XCTestCase {
    private func mockServer(stall: Bool = false) throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let script = root.appendingPathComponent("server.py"), log = root.appendingPathComponent("methods.txt")
        let body = """
        #!/usr/bin/python3
        import sys,json,time
        for line in sys.stdin:
            msg=json.loads(line)
            method=msg.get('method')
            with open(\(String(reflecting: log.path)), 'a') as log: log.write(str(method)+'\\n')
            if \(stall ? "True" : "False"): continue
            if method=='initialize':
                print(json.dumps({'id':msg['id'],'result':{'ready':True}}),flush=True)
            elif method=='account/rateLimits/read':
                print(json.dumps({'id':msg['id'],'result':{'rateLimits':{'limitId':'codex','primary':{'usedPercent':42,'windowDurationMins':300,'resetsAt':time.time()+3600},'planType':'plus'}}}),flush=True)
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return (root, script, log)
    }
    func testHandshakeReadOnlyRequestsCachingAndCleanup() async throws {
        let (root, executable, log) = try mockServer(); defer { try? FileManager.default.removeItem(at: root) }
        let client = CodexLiveQuotaClient(executable: executable), consumer = UUID()
        client.acquire(consumer)
        let one = await client.read()
        XCTAssertEqual(one?.primary.utilization, 42); XCTAssertTrue(client.isRunning)
        let two = await client.read()
        XCTAssertEqual(one?.recordedAt, two?.recordedAt, "Repeated immediate reads share the latest successful response")
        let methods = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
        client.release(consumer)
        XCTAssertEqual(client.consumerCount, 0); XCTAssertFalse(client.isRunning)
    }
    func testLastConsumerReleaseCancelsPendingRequestAndStopsChild() async throws {
        let (root, executable, _) = try mockServer(stall: true); defer { try? FileManager.default.removeItem(at: root) }
        let client = CodexLiveQuotaClient(executable: executable), first = UUID(), second = UUID()
        client.acquire(first); client.acquire(second)
        let read = Task { await client.read() }
        for _ in 0..<100 {
            if client.isRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(client.isRunning)
        client.release(first); XCTAssertEqual(client.consumerCount, 1); XCTAssertTrue(client.isRunning)
        client.release(second)
        let result = await read.value
        XCTAssertNil(result); XCTAssertFalse(client.isRunning)
    }
    func testNoConsumerCannotStartProcess() async {
        let client = CodexLiveQuotaClient(executable: URL(fileURLWithPath: "/does/not/exist"))
        let result = await client.read()
        XCTAssertNil(result); XCTAssertFalse(client.isRunning)
    }
    func testLiveMultiBucketParsingAndSnapshotTimestamp() throws {
        let now = Date()
        let limit: [String: Any] = ["limitId":"codex", "planType":"plus",
            "primary":["usedPercent":15, "windowDurationMins":300, "resetsAt":now.addingTimeInterval(3600).timeIntervalSince1970],
            "secondary":["usedPercent":79, "windowDurationMins":10080, "resetsAt":now.addingTimeInterval(86400).timeIntervalSince1970]]
        let quota = try XCTUnwrap(CodexLiveQuotaClient.parse(["rateLimitsByLimitId":["codex":limit],"rateLimits":["limitId":"other"]], now: now))
        XCTAssertEqual(quota.primary.utilization, 15); XCTAssertEqual(quota.secondary?.utilization, 79)
        XCTAssertEqual(quota.recordedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.01)
        let summary = AIUsageService.computeCodexSummary(sessions: [], config: CodexConfigData(), now: now, quota: quota, isLive: true)
        XCTAssertTrue(summary.isLiveAPI); XCTAssertTrue(summary.isQuotaFresh(at: now))
        XCTAssertFalse(summary.isQuotaFresh(at: now.addingTimeInterval(180)))
        XCTAssertNil(CodexLiveQuotaClient.parse(["rateLimits":["limitId":"other"]], now: now))
    }
}
