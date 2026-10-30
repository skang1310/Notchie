import Foundation
import Combine
import SwiftUI

@MainActor
final class AIUsagePreferences: ObservableObject {
    static let shared = AIUsagePreferences()
    private let defaults: UserDefaults
    @Published var alertsEnabled: Bool { didSet { defaults.set(alertsEnabled, forKey: "aiUsage.alerts") } }
    @Published var threshold: Int { didSet { defaults.set(threshold, forKey: "aiUsage.threshold") } }
    @Published var countdownEnabled: Bool { didSet { defaults.set(countdownEnabled, forKey: "aiUsage.countdown") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        alertsEnabled = defaults.bool(forKey: "aiUsage.alerts")
        let saved = defaults.integer(forKey: "aiUsage.threshold")
        threshold = [70,80,90,95].contains(saved) ? saved : 90
        countdownEnabled = defaults.object(forKey: "aiUsage.countdown") as? Bool ?? true
    }
}

/// One warning per high-usage episode. Local estimates never claim provider quota.
nonisolated struct AIQuotaAlertGate {
    private(set) var warned: Set<String> = []
    mutating func evaluate(_ summary: AIProviderUsageSummary, threshold: Int, now: Date) -> [AIQuotaWindow] {
        guard summary.hasRecordedQuota, summary.isQuotaFresh(at: now) else { return [] }
        var result: [AIQuotaWindow] = []
        for window in [summary.primaryWindow, summary.secondaryWindow].compactMap({ $0 }) + summary.additionalWindows {
            let key = summary.provider.rawValue + ":" + window.id
            if window.utilization < Double(threshold - 5) { warned.remove(key) }
            guard window.utilization.isFinite, window.resetsAt > now else { continue }
            if window.utilization >= Double(threshold), warned.insert(key).inserted { result.append(window) }
        }
        return result
    }
}

@MainActor
final class AIQuotaMonitor {
    static let shared = AIQuotaMonitor()
    private var observations = Set<AnyCancellable>()
    private var task: Task<Void, Never>?
    private let liveConsumer = UUID()
    private var gate = AIQuotaAlertGate(warned: Set(UserDefaults.standard.stringArray(forKey: "aiUsage.warnedWindows") ?? []))
    func start() {
        guard observations.isEmpty else { return }
        let preferences = AIUsagePreferences.shared
        preferences.$alertsEnabled.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.configure(enabled) }.store(in: &observations)
        AIUsageService.shared.$codexSummary.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.check() }.store(in: &observations)
        AIUsageService.shared.$claudeSummary.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.check() }.store(in: &observations)
        AIUsageService.shared.$lastRefreshed.compactMap { $0 }.receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.check() }.store(in: &observations)
    }
    private func configure(_ enabled: Bool) {
        task?.cancel(); task = nil
        CodexLiveQuotaClient.shared.release(liveConsumer)
        guard enabled, !AppEnvironment.isRunningTests else { return }
        CodexLiveQuotaClient.shared.acquire(liveConsumer)
        task = Task { @MainActor in
            while !Task.isCancelled {
                await AIUsageService.shared.refreshIfNeeded()
                await AIUsageService.shared.refreshQuotasAsync()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }
    private func check() {
        guard AIUsagePreferences.shared.alertsEnabled,
              let model = QuickToolsStore.shared.notchViewModel, !model.isLocked,
              !model.notchModel.isExpanded, !QuickToolsStore.shared.isNotchHubPinned,
              !model.isActivityPresentationHidden else { return }
        let service = AIUsageService.shared
        for summary in [service.claudeSummary, service.codexSummary, service.geminiSummary].compactMap({ $0 }) {
            if let window = gate.evaluate(summary, threshold: AIUsagePreferences.shared.threshold, now: .now).first {
                model.send(.showTemporaryNotification(AIQuotaWarningContent(summary: summary, window: window), duration: 5))
                break
            }
        }
        UserDefaults.standard.set(Array(gate.warned), forKey: "aiUsage.warnedWindows")
    }
    func stop() { CodexLiveQuotaClient.shared.release(liveConsumer); task?.cancel(); task = nil; observations.removeAll() }
}

struct AIQuotaWarningContent: NotchContentProtocol {
    let summary: AIProviderUsageSummary
    let window: AIQuotaWindow
    var id: String { "ai.warning." + summary.provider.rawValue }
    var isRestorable: Bool { false }
    var strokeColor: Color { .orange }
    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize { CGSize(width: max(340, baseWidth + 120), height: baseHeight + 34) }
    @MainActor func compactView() -> AnyView {
        AnyView(HStack(spacing: 8) {
            AIProductLogoView(provider: summary.provider, size: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.provider.displayName + " · " + privacyText("High usage", "사용량 주의"))
                Text(privacyText("Recorded quota · ", "서비스 한도 기록 · ") + String(format: "%.0f%%", window.utilization))
                    .font(.caption).foregroundStyle(.secondary)
            }.font(.caption.bold())
        }.padding(8))
    }
    var windowLink: (@MainActor () -> Void)? {
        { QuickToolsStore.shared.hubMode = .ai
          NotificationCenter.default.post(name: .showQuickToolsInNotch, object: nil) }
    }
}
