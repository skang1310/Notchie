import Testing
import CoreGraphics
@testable import HeyMacEngine

@Test func secureFieldPlanUsesRealLayoutKeyAndShiftAlongsideUnicode() {
    let plan = KeystrokeInjector.presses(for: "aA!", layout: [
        "a": .init(code: 0, flags: []), "A": .init(code: 0, flags: .maskShift),
        "!": .init(code: 18, flags: .maskShift)
    ])
    #expect(plan.map(\.virtualKey) == [0, 0, 18, 36])
    #expect(plan[0].flags.isEmpty)
    #expect(plan[1].flags == .maskShift)
    #expect(plan[2].flags == .maskShift)
    #expect(plan[2].unicode == Array("!".utf16))
    #expect(plan.last?.unicode == nil)
    #expect(plan.last?.flags.isEmpty == true)
    #expect(plan.last?.waitAfterRelease == false)
}

@Test func nonUSLayoutMappingIsUsedWithoutCommandOrControl() {
    let plan = KeystrokeInjector.presses(for: "z", layout: ["z": .init(code: 6, flags: [])])
    #expect(plan.first?.virtualKey == 6)
    #expect(plan.first?.flags.isEmpty == true)
}

@Test @MainActor func realKeyboardLayoutCanBeReadFromVerificationWorker() async {
    // Exercise the production Carbon path rather than the injected mapping fixtures.
    // Planning is read-only: this test never posts keyboard events or reads credentials.
    let plan = await Task.detached {
        KeystrokeInjector.presses(for: "aA1!")
    }.value
    #expect(plan.count == 5)
    #expect(plan[2].virtualKey != 0)
    #expect(plan[0].unicode == Array("a".utf16))
    #expect(plan[1].flags.contains(.maskShift))
    #expect(plan.last?.virtualKey == 36)
}
