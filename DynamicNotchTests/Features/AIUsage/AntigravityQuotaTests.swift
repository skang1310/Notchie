import XCTest
@testable import DynamicNotch

@MainActor
final class AntigravityQuotaTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func payload(_ buckets: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["response": ["groups": [["displayName": "Gemini Models", "buckets": buckets]]]])
    }
    private func bucket(_ label: String, _ fraction: Any) -> [String: Any] {
        ["displayName": label, "remainingFraction": fraction, "resetTime": "2030-01-01T01:00:00Z"]
    }
    func testActualGroupedSchemaPreservesIndependentLimitsAndZero() throws {
        let groups: [[String: Any]] = [
            ["displayName": "Gemini Models", "buckets": [bucket("Weekly Limit Remaining", 0.63), bucket("Five Hour Limit Remaining", 0.91)]],
            ["displayName": "Claude and GPT models", "buckets": [bucket("Weekly Limit Remaining", 0.49), bucket("Five Hour Limit Remaining", 0.0)]],
            ["displayName": "Gemini 4 Argon", "buckets": [bucket("Gemini 4 Argon Weekly Limit", 0.007)]]]
        let data = try JSONSerialization.data(withJSONObject: ["response": ["groups": groups]])
        let quota = try XCTUnwrap(AntigravityQuotaClient.parse(data, now: now))
        XCTAssertEqual(quota.windows.count, 5)
        XCTAssertEqual(quota.windows[3].utilization, 100)
        XCTAssertEqual(quota.windows[4].remainingPercentage, 0.7, accuracy: 0.001)
        let summary = AIUsageService.computeGeminiSummary(sessions: [], modelName: "unknown", now: now, quota: quota)
        XCTAssertEqual(summary.provider.shortDisplayName, "Antigravity")
        XCTAssertEqual(summary.additionalWindows.count, 3)
        XCTAssertTrue(summary.hasRecordedQuota); XCTAssertTrue(summary.isQuotaFresh(at: now))
        XCTAssertFalse(summary.isQuotaFresh(at: now.addingTimeInterval(121)))
        var gate = AIQuotaAlertGate()
        XCTAssertEqual(gate.evaluate(summary, threshold: 90, now: now).count, 2)
        XCTAssertTrue(gate.evaluate(summary, threshold: 90, now: now).isEmpty)
    }
    func testInvalidAndMissingFractionsNeverInventZeroQuota() throws {
        var absent = bucket("Missing", 0.0); absent.removeValue(forKey: "remainingFraction")
        let data = try payload([absent, bucket("Boolean", true), bucket("Negative", -0.1), bucket("Too high", 1.1), bucket("String", "0.5")])
        XCTAssertNil(AntigravityQuotaClient.parse(data, now: now))
        XCTAssertNil(AntigravityQuotaClient.parse(Data("{}".utf8), now: now))
    }
    func testStableIdentifiersDeduplicateAndDoNotMergeDifferentGroups() throws {
        let data = try payload([bucket("Weekly", 0.4), bucket("Weekly", 0.4)])
        let snapshot = try XCTUnwrap(AntigravityQuotaClient.parse(data, now: now))
        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertTrue(snapshot.windows[0].titleKo.contains("주간"))
    }
    func testDiscoveryOnlyAcceptsTrustedExecutableAndLoopbackPorts() {
        let command = "/Applications/Antigravity.app/Contents/Resources/bin/language_server --standalone --csrf_token 12345678-abcd-1234-abcd-123456789abc --https_server_port 0"
        let endpoint = AntigravityQuotaClient.endpoint(command: command, port: 54321)
        XCTAssertEqual(endpoint?.url.host, "127.0.0.1")
        XCTAssertEqual(endpoint?.url.scheme, "http")
        XCTAssertNil(AntigravityQuotaClient.endpoint(command: command.replacingOccurrences(of: "/Applications/", with: "/tmp/"), port: 54321))
        XCTAssertNil(AntigravityQuotaClient.endpoint(command: command, port: 0))
        XCTAssertNil(AntigravityQuotaClient.endpoint(command: command.replacingOccurrences(of: "--csrf_token", with: "--other"), port: 54321))
    }
    func testReadOnlyTransportCacheAndFailedReadPreserveOriginalTimestamp() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AntigravityQuotaMockProtocol.self]
        let client = AntigravityQuotaClient(configuration: config,
            endpoints: [.init(port: 54321, csrf: "test-local-csrf")])
        let fetched = await client.read(now: now)
        let first = try XCTUnwrap(fetched)
        let cached = await client.read(now: now.addingTimeInterval(5))
        XCTAssertEqual(cached?.recordedAt, first.recordedAt)
        let failed = await client.read(now: now.addingTimeInterval(11))
        XCTAssertEqual(failed?.recordedAt, first.recordedAt)
    }
}

private final class AntigravityQuotaMockProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var calls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.calls += 1; let call = Self.calls; Self.lock.unlock()
        let valid = request.url?.host == "127.0.0.1" && request.url?.path.hasSuffix("/RetrieveUserQuotaSummary") == true
            && request.httpMethod == "POST" && request.value(forHTTPHeaderField: "X-Codeium-Csrf-Token") == "test-local-csrf"
        let response = HTTPURLResponse(url: request.url!, statusCode: valid && call == 1 ? 200 : 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"response":{"groups":[{"displayName":"Gemini Models","buckets":[{"displayName":"Weekly Limit Remaining","remainingFraction":0.63,"resetTime":"2030-01-01T01:00:00Z"}]}]}}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
