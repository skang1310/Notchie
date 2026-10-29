import XCTest
@testable import DynamicNotch

final class LoginPasswordValidatorTests: XCTestCase {
    func testRejectedPasswordNeverReplacesSavedCredential() {
        struct Rejected: Error {}
        var persisted = false
        XCTAssertThrowsError(try LoginPasswordValidator.save("fixture", validate: { _ in throw Rejected() }, persist: { _ in persisted = true }))
        XCTAssertFalse(persisted)
    }
    func testVerifiedPasswordIsSavedOnlyAfterValidation() throws {
        var operations: [String] = []
        try LoginPasswordValidator.save("fixture", validate: { _ in operations.append("verify") }, persist: { _ in operations.append("save") })
        XCTAssertEqual(operations, ["verify", "save"])
    }
}
