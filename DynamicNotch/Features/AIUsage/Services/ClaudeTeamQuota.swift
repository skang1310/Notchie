import Foundation
import Combine
import ApplicationServices

@MainActor
final class ClaudeTeamConnection: ObservableObject {
    static let shared = ClaudeTeamConnection()
    private let defaults: UserDefaults
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "aiUsage.claudeTeam.enabled") }
    }
    private(set) var snapshot: RecordedAIQuota?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "aiUsage.claudeTeam.enabled")
        snapshot = defaults.data(forKey: "aiUsage.claudeTeam.snapshot").flatMap { try? JSONDecoder().decode(RecordedAIQuota.self, from: $0) }
    }
    func save(_ quota: RecordedAIQuota) {
        guard enabled, quota.plan == "Team · Personal" else { return }
        snapshot = quota
        if let data = try? JSONEncoder().encode(quota) { defaults.set(data, forKey: "aiUsage.claudeTeam.snapshot") }
    }
}

nonisolated struct ClaudeUsageElement: Sendable {
    let label: String
    var value: Double? = nil
}

/// Reads only the already-open Team usage settings page. No cookies, credentials, JS or navigation.
/// Chrome builds its web accessibility tree only when an assistive client asks for it, so the reader
/// sets Chromium's `AXManualAccessibility` flag on Chrome (opt-in path only); the first pass after that
/// may see an empty page and the next refresh reads it.
nonisolated enum ClaudeTeamQuotaReader {
    static let windowVisitLimit = 1500
    static let pageVisitLimit = 2500
    static func isUsageURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "claude.ai" &&
            (url.path == "/settings/usage" || url.fragment == "settings/usage")
    }
    static func capture(browserPID: pid_t, now: Date = .now) -> RecordedAIQuota? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(browserPID)
        AXUIElementSetMessagingTimeout(app, 0.25)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        // Visible windows first; a minimized usage window is still read so it can stay out of the way.
        let candidates = Array(windows.prefix(6))
        let minimized = candidates.map { attribute($0, kAXMinimizedAttribute) as? Bool == true }
        let ordered = candidates.indices.filter { !minimized[$0] }.map { candidates[$0] } + candidates.indices.filter { minimized[$0] }.map { candidates[$0] }
        for window in ordered {
            var stack = [window], visited = 0
            while let element = stack.popLast(), visited < windowVisitLimit, ProcessInfo.processInfo.systemUptime < deadline {
                visited += 1
                let values = attributes(element, [kAXRoleAttribute, kAXURLAttribute, kAXChildrenAttribute])
                let role = values[0] as? String
                if role == "AXWebArea" {
                    let url = (values[1] as? URL) ?? (values[1] as? String).flatMap(URL.init(string:))
                    guard let url, isUsageURL(url) else { continue }
                    if let quota = parse(elements: usageElements(element, deadline: deadline), now: now) { return quota }
                    continue
                }
                // Browser chrome (toolbars/tab strip) never contains the page.
                if role == "AXToolbar" || role == "AXTabGroup" { continue }
                if let children = values[2] as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
            }
        }
        return nil
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    /// One IPC round trip per element instead of one per attribute.
    private static func attributes(_ element: AXUIElement, _ names: [String]) -> [AnyObject?] {
        AXUIElementSetMessagingTimeout(element, 0.1)
        var raw: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, names as CFArray, AXCopyMultipleAttributeOptions(), &raw) == .success,
              let array = raw as [AnyObject]?, array.count == names.count else { return names.map { _ in nil } }
        return array.map { value in
            if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError { return nil }
            return value
        }
    }
    private static func usageElements(_ root: AXUIElement, deadline: TimeInterval) -> [ClaudeUsageElement] {
        let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXChildrenAttribute]
        var stack = [root], result: [ClaudeUsageElement] = [], count = 0, focusedDialog = false
        while let element = stack.popLast(), count < pageVisitLimit, ProcessInfo.processInfo.systemUptime < deadline {
            count += 1
            let v = attributes(element, names)
            let role = v[0] as? String ?? "", subrole = v[1] as? String ?? ""
            // The settings modal holds the usage rows; restart inside it and drop the sidebar/chat list.
            if !focusedDialog, role == "AXDialog" || subrole == "AXApplicationDialog" || subrole == "AXDialog" {
                focusedDialog = true; result.removeAll(); stack.removeAll()
            }
            if subrole == "AXLandmarkNavigation" { continue }
            let text = v[4] as? String ?? ""
            let label = [v[2] as? String ?? "", v[3] as? String ?? "", text].filter { !$0.isEmpty }.joined(separator: " ")
            if !label.isEmpty { result.append(ClaudeUsageElement(label: label, value: (v[4] as? NSNumber)?.doubleValue)) }
            if let children = v[5] as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
        }
        return result
    }
    static func parse(elements: [ClaudeUsageElement], now: Date, calendar: Calendar = .current) -> RecordedAIQuota? {
        let labels = elements.map { $0.label.lowercased() }
        // "사용 한도" and its "팀" badge may be one element or adjacent elements.
        let isTeam = labels.indices.contains { index in
            guard labels[index].contains("사용 한도") || labels[index].contains("usage limits") else { return false }
            return labels[index..<min(labels.count, index + 4)].contains { $0.contains("팀") || $0.range(of: #"\bteam\b"#, options: .regularExpression) != nil }
        }
        guard isTeam else { return nil }
        func window(matches: [String], id: String, title: String, ko: String) -> AIQuotaWindow? {
            guard let titleIndex = labels.firstIndex(where: { label in matches.contains { label.contains($0) } }) else { return nil }
            let after = titleIndex..<min(elements.count, titleIndex + 7)
            let used: Double
            if let valued = after.first(where: { index in
                elements[index].value != nil && matches.contains { labels[index].contains($0) }
            }) {
                guard let value = elements[valued].value, value.isFinite, (0...100).contains(value) else { return nil }
                used = value
            } else if let text = after.lazy.compactMap({ percentUsed(elements[$0].label) }).first {
                used = text
            } else { return nil }
            let nearby = (max(0, titleIndex - 4)..<min(elements.count, titleIndex + 5)).sorted { abs($0 - titleIndex) < abs($1 - titleIndex) }
            let reset = nearby.lazy.compactMap { resetDate(elements[$0].label, now: now, calendar: calendar) }.first
            guard let reset, id != "claude-team-5h" || reset.timeIntervalSince(now) <= 5 * 3600 else { return nil }
            return AIQuotaWindow(id: id, title: title, titleKo: ko, subtitle: "Team account usage page", subtitleKo: "Team 계정 사용량 화면",
                utilization: used, resetsAt: reset)
        }
        guard let primary = window(matches: ["현재 세션", "current session"], id: "claude-team-5h", title: "Current session", ko: "현재 세션") else { return nil }
        let secondary = window(matches: ["모든 모델", "all models"], id: "claude-team-7d", title: "Weekly · all models", ko: "주간 · 모든 모델")
        return RecordedAIQuota(primary: primary, secondary: secondary, recordedAt: now, plan: "Team · Personal")
    }
    /// "42% 사용됨" / "42% used" text shown next to the bar.
    static func percentUsed(_ text: String) -> Double? {
        guard let match = text.range(of: #"(\d{1,3}(?:\.\d+)?)\s*%\s*(사용|used)"#, options: [.regularExpression, .caseInsensitive]),
              let number = text[match].range(of: #"\d{1,3}(?:\.\d+)?"#, options: .regularExpression),
              let value = Double(text[match][number]), (0...100).contains(value) else { return nil }
        return value
    }
    static func resetDate(_ text: String, now: Date, calendar: Calendar) -> Date? {
        guard text.contains("초기화") || text.lowercased().contains("reset") else { return nil }
        let regex = try! NSRegularExpression(pattern: "(?:(오전|오후|AM|PM)\\s*)?(\\d{1,2}):(\\d{2})\\s*(AM|PM)?", options: .caseInsensitive)
        let source = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: source.length)),
              let hour = Int(source.substring(with: match.range(at: 2))), let minute = Int(source.substring(with: match.range(at: 3))),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        func group(_ index: Int) -> String { match.range(at: index).location == NSNotFound ? "" : source.substring(with: match.range(at: index)).uppercased() }
        let period = group(1) + group(4)
        if !period.isEmpty && !(1...12).contains(hour) { return nil }
        let resolvedHour = period.isEmpty ? hour : hour % 12 + (period.contains("PM") || period.contains("오후") ? 12 : 0)
        var components = DateComponents(hour: resolvedHour, minute: minute)
        let koDays = ["일", "월", "화", "수", "목", "금", "토"]
        let enDays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        for day in 0..<7 {
            if text.contains("(\(koDays[day]))") || text.contains(koDays[day] + "요일") || text.lowercased().contains(enDays[day]) {
                components.weekday = day + 1; break
            }
        }
        guard let date = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime),
              date.timeIntervalSince(now) <= 8 * 86400 else { return nil }
        return date
    }
}
