import Foundation
import OpenDirectory

/// Runs only for an explicit Save action. Never logs or retains the supplied password.
nonisolated enum LoginPasswordValidator {
    static func verify(_ password: String) throws {
        let node = try ODNode(session: ODSession.default(), type: UInt32(kODNodeTypeAuthentication))
        let record = try node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
        try record.verifyPassword(password)
    }

    /// Validate first: a typo or directory failure must preserve the previously saved credential.
    static func save(_ password: String, validate: (String) throws -> Void,
                     persist: (String) throws -> Void) throws {
        try validate(password)
        try persist(password)
    }
}
