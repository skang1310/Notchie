import Foundation

/// One delivery route per action: successful app commands must never be repeated as a global toggle.
enum NowPlayingCommandDelivery {
    static func deliver(application: () async -> Bool, fallback: () -> Void) async -> Bool {
        if await application() { return true }
        fallback()
        return false
    }
}
