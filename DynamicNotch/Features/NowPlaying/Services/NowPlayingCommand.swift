import Foundation

enum NowPlayingCommand: Equatable, Sendable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seek(TimeInterval)
    case setShuffle(Bool)
    case setRepeatMode(NowPlayingRepeatMode)
    case setVolume(Double)
    case setFavorite(Bool)
}
