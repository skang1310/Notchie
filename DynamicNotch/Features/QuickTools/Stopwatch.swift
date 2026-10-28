import Foundation
import Combine

struct StopwatchState: Sendable {
    private(set) var accumulated: Duration = .zero
    private(set) var startedAt: ContinuousClock.Instant?
    var isRunning: Bool { startedAt != nil }
    func elapsed(at now: ContinuousClock.Instant) -> Duration {
        accumulated + (startedAt.map { max(.zero, $0.duration(to: now)) } ?? .zero)
    }
    mutating func start(at now: ContinuousClock.Instant) {
        if startedAt == nil { startedAt = now }
    }
    mutating func pause(at now: ContinuousClock.Instant) {
        accumulated = elapsed(at: now)
        startedAt = nil
    }
    mutating func reset() { accumulated = .zero; startedAt = nil }
    static func formatted(_ duration: Duration) -> String {
        let seconds = max(0, duration.components.seconds)
        return String(format: "%02lld:%02lld:%02lld", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}
@MainActor
final class StopwatchController: ObservableObject {
    @Published private(set) var state = StopwatchState()
    var activityChanged: ((Bool) -> Void)?
    func start() { state.start(at: .now); activityChanged?(true) }
    func pause() { state.pause(at: .now); activityChanged?(false) }
    func reset() { state.reset(); activityChanged?(false) }
}
