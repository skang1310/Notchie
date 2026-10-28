import Foundation

nonisolated enum AppPresentationPolicy {
    static func hides(bundleID: String?, rules: [String]) -> Bool {
        guard let bundleID, bundleID != "com.Jackson.DynamicNotch" else { return false }
        return rules.contains(bundleID)
    }
}
