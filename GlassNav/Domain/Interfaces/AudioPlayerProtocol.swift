import Foundation

/// Represents the high-level playback state of the audio player.
public enum PlaybackState: Sendable, Equatable {
    case stopped
    case buffering
    case playing
    case paused
}

/// Domain abstraction for audio playback with background capabilities.
@MainActor
public protocol AudioPlayerProtocol: AnyObject, Sendable {
    /// Currently loaded or playing episode.
    var currentEpisode: Episode? { get }

    /// Active playback state.
    var playbackState: PlaybackState { get }

    /// Current playback position in seconds.
    var currentTime: TimeInterval { get }

    /// Duration of the currently playing audio in seconds.
    var duration: TimeInterval { get }

    /// Starts or resumes playback for the given episode.
    func play(episode: Episode)

    /// Toggles play/pause for the given episode.
    func togglePlay(episode: Episode)

    /// Pauses current playback.
    func pause()

    /// Resumes playback if paused.
    func resume()

    /// Stops playback and releases audio resources.
    func stop()

    /// Seeks playback to a specific timestamp.
    func seek(to time: TimeInterval)

    /// Returns true if the specified episode is currently playing.
    func isPlaying(episodeId: String) -> Bool
}

extension AudioPlayerProtocol {
    public func isPlaying(episodeId: String) -> Bool {
        currentEpisode?.id == episodeId && playbackState == .playing
    }
}
