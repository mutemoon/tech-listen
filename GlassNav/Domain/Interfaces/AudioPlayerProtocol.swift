import Foundation

/// Represents the high-level playback state of the audio player.
public enum PlaybackState: Sendable, Equatable {
    case stopped
    case buffering
    case playing
    case paused
}

/// Represents the fine-grained lifecycle of sentence-by-sentence intensive listening.
public enum SentencePlaybackState: Sendable, Equatable {
    /// No audio loaded or player stopped.
    case idle
    /// Parked and ready at the sentence start position (paused, ready to play instantly).
    case ready(segmentId: String, position: TimeInterval)
    /// Buffering audio for the active sentence.
    case buffering(segmentId: String)
    /// Actively playing the specified sentence.
    case playing(segmentId: String, position: TimeInterval)
    /// Paused mid-sentence by user request.
    case paused(segmentId: String, position: TimeInterval)
    /// Finished playing to the end boundary of the sentence.
    case completed(segmentId: String)

    /// Indicates whether audio is currently rendering sound.
    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    /// Active segment ID if any.
    public var segmentId: String? {
        switch self {
        case .idle: return nil
        case .ready(let id, _), .buffering(let id), .playing(let id, _), .paused(let id, _), .completed(let id):
            return id
        }
    }
}

/// Domain abstraction for audio playback in tech-listen intensive listening app.
@MainActor
public protocol AudioPlayerProtocol: AnyObject, Sendable {
    /// Currently loaded episode.
    var currentEpisode: Episode? { get }

    /// Currently active transcript segment.
    var currentSegment: TranscriptSegment? { get }

    /// Boundary timestamp where the current sentence stops playing.
    var currentSegmentEndTime: Double? { get }

    /// Coarse-grained general playback state.
    var playbackState: PlaybackState { get }

    /// Sentence-centric playback state machine.
    var sentenceState: SentencePlaybackState { get }

    /// Whether audio is actively playing.
    var isPlaying: Bool { get }

    /// Current playback position in seconds.
    var currentTime: TimeInterval { get }

    /// Duration of the current episode audio in seconds.
    var duration: TimeInterval { get }

    /// Current playback speed rate.
    var playbackRate: Float { get }

    // MARK: - Sentence-Oriented Lifecycle Methods

    /// Parks the player at the start of a sentence in a ready (paused) state without auto-playing.
    func park(on segment: TranscriptSegment, in episode: Episode, endTime: Double)

    /// Plays a specific sentence from its start (or target position), automatically pausing at endTime.
    func play(segment: TranscriptSegment, in episode: Episode, endTime: Double)

    /// Toggles play/pause: resumes if paused/ready, replays if completed, pauses if playing.
    func togglePlayPause()

    /// Replays the current sentence from its start timestamp.
    func replayCurrentSentence()

    /// Pauses playback.
    func pause()

    /// Stops playback and releases audio resources.
    func stop()

    /// Seeks playback to a specific timestamp with optional completion callback.
    func seek(to time: TimeInterval, completion: (@MainActor @Sendable (Bool) -> Void)?)

    /// Sets playback speed rate.
    func setPlaybackRate(_ rate: Float)

    /// Updates the boundary timestamp for the current active segment.
    func updateCurrentSegmentBoundary(_ segment: TranscriptSegment, endTime: Double)
}

public extension AudioPlayerProtocol {
    func seek(to time: TimeInterval) {
        seek(to: time, completion: nil)
    }
}

