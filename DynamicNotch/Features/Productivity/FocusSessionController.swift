import Foundation
import Combine

@MainActor
final class FocusSessionController: ObservableObject {
    enum Phase { case idle, focus, readyForBreak, rest, complete }
    let timer = LocalTimerViewModel()
    let awake = KeepAwakeController()
    @Published private(set) var phase: Phase = .idle
    @Published var preventSleep = false
    @Published private(set) var persistenceError: String?
    private let storage: ProductivityStorage
    private var focusSeconds = 0
    private var observation: AnyCancellable?
    init(storage: ProductivityStorage? = nil) {
        self.storage = storage ?? .shared
        timer.onTimerFinished = { [weak self] in self?.finished() }
        observation = timer.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }
    func startFocus(minutes: Int = 25) {
        guard (1...180).contains(minutes), phase == .idle || phase == .complete else { return }
        focusSeconds = minutes * 60; phase = .focus
        timer.start(hours: 0, minutes: minutes, seconds: 0)
        if preventSleep { awake.start(seconds: Double(focusSeconds)) }
    }
    func startBreak(minutes: Int = 5) {
        guard phase == .readyForBreak, (1...60).contains(minutes) else { return }
        phase = .rest; timer.start(hours: 0, minutes: minutes, seconds: 0)
    }
    func pauseOrResume() {
        guard phase == .focus || phase == .rest else { return }
        if timer.state == .running { timer.pause(); awake.stop() }
        else if timer.state == .paused {
            timer.resume()
            if phase == .focus && preventSleep { awake.start(seconds: timer.remainingTime) }
        }
    }
    func stop() { timer.stop(); awake.stop(); phase = .idle }
    func finished() {
        guard phase == .focus || phase == .rest else { return }
        awake.stop()
        if phase == .focus {
            let saved = storage.update { doc in doc.focusHistory.append(FocusCompletion(date: .now, seconds: focusSeconds)) }
            persistenceError = saved ? nil : storage.error
            phase = .readyForBreak
        } else { phase = .complete }
        NotificationCenter.default.post(name: .focusSessionCompleted, object: nil)
    }
}

extension Notification.Name { static let focusSessionCompleted = Notification.Name("DynamicNotch.FocusSessionCompleted") }
