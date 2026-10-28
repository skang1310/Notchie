import Foundation
import Combine
internal import IOKit.pwr_mgt

@MainActor
protocol KeepAwakeAccess {
    func acquire() throws -> IOPMAssertionID
    func release(_ id: IOPMAssertionID)
}
@MainActor
struct SystemKeepAwakeAccess: KeepAwakeAccess {
    func acquire() throws -> IOPMAssertionID {
        var id = IOPMAssertionID(kIOPMNullAssertionID)
        let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "DynamicNotch user-requested Keep Awake" as CFString, &id)
        guard status == kIOReturnSuccess else { throw NSError(domain: "DynamicNotch.KeepAwake", code: Int(status)) }
        return id
    }
    func release(_ id: IOPMAssertionID) { IOPMAssertionRelease(id) }
}
@MainActor
final class KeepAwakeController: ObservableObject {
    @Published private(set) var until: Date?
    @Published private(set) var error: String?
    private var assertion: IOPMAssertionID?
    private var expiry: Task<Void, Never>?
    private let access: any KeepAwakeAccess
    init(access: (any KeepAwakeAccess)? = nil) { self.access = access ?? SystemKeepAwakeAccess() }
    func start(seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0, seconds <= 86400 else { return }
        stop()
        do {
            assertion = try access.acquire()
            until = Date().addingTimeInterval(seconds)
            error = nil
            expiry = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                self?.stop()
            }
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        expiry?.cancel(); expiry = nil
        if let assertion { access.release(assertion) }
        assertion = nil
        until = nil
    }
}
