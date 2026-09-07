import Foundation

/// Domain abstraction for the global application state.
/// Centralizes top-level navigation, active episode selection, startup state restoration, and cross-tab triggers.
@MainActor
public protocol AppStateProtocol: AnyObject, Sendable {
    /// The currently selected root navigation tab.
    var selectedTab: TabItem { get set }

    /// The active episode across dictation, playback, and transcript views. Nil indicates empty state.
    var activeEpisode: Episode? { get set }

    /// Restored playback position in seconds for the active episode if resuming from history.
    var restoredPlaybackPosition: Double? { get set }

    /// Loaded transcript segments for the active episode.
    var currentSegments: [TranscriptSegment] { get set }

    /// Currently focused sentence index in `currentSegments`.
    var currentSegmentIndex: Int { get set }

    /// Currently active sentence segment.
    var currentSegment: TranscriptSegment? { get }

    /// Sets the active episode and switches navigation to the player tab.
    func openEpisode(_ episode: Episode)

    /// Restores the startup active episode based on priority:
    /// 1. Resume from last played episode and position
    /// 2. Start from latest available episode
    /// 3. If no episodes exist, remain nil (empty state)
    func restoreInitialState(using repository: any EpisodeRepositoryProtocol) async

    /// Populates transcript segments for the active episode and restores position if applicable.
    func setSegments(_ segments: [TranscriptSegment])

    /// Selects a specific sentence index.
    func selectSegment(at index: Int)

    /// Navigates to previous sentence.
    func previousSegment()

    /// Navigates to next sentence.
    func nextSegment()

    /// Plays the current sentence, pausing strictly at sentence end.
    func playCurrentSentence(using player: any AudioPlayerProtocol)

    /// Toggles play/pause for the current sentence.
    func togglePlayCurrentSentence(using player: any AudioPlayerProtocol)

    /// Records the current playback progress for the given episode.
    func recordPlaybackProgress(for episode: Episode, at seconds: Double)
}

