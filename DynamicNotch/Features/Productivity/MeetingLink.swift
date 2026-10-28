import Foundation

nonisolated enum MeetingLink {
    private static let domains = ["meet.google.com", "zoom.us", "zoom.com", "teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft", "webex.com"]
    static func accepted(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
              let host = parts.host?.lowercased() else { return false }
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func first(url: URL?, notes: String?, location: String?) -> URL? {
        if let url, accepted(url) { return url }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let text = [location, notes].compactMap { $0 }.joined(separator: "\n")
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url).first(where: accepted)
    }
}
