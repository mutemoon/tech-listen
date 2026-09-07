import Foundation
import SwiftUI

/// Concrete observable implementation of AppStateProtocol managing global app state.
@Observable
@MainActor
public final class StandardAppState: AppStateProtocol {
    public var selectedTab: TabItem {
        didSet {
            userDefaults.set(selectedTab.rawValue, forKey: selectedTabKey)
        }
    }
    public var activeEpisode: Episode?
    public var restoredPlaybackPosition: Double?
    public var currentSegments: [TranscriptSegment] = []
    public var currentSegmentIndex: Int = 0

    public var currentSegment: TranscriptSegment? {
        guard currentSegmentIndex >= 0 && currentSegmentIndex < currentSegments.count else { return nil }
        return currentSegments[currentSegmentIndex]
    }

    private let userDefaults: UserDefaults
    private let downloadManager: (any DownloadManagerProtocol)?
    private let lastEpisodeKey = "tech_listen_last_episode_id"
    private let lastPositionKey = "tech_listen_last_position_seconds"
    private let selectedTabKey = "tech_listen_selected_tab"

    public init(
        initialTab: TabItem = .episodes,
        initialEpisode: Episode? = nil,
        downloadManager: (any DownloadManagerProtocol)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.selectedTab = initialTab
        self.activeEpisode = initialEpisode
        self.downloadManager = downloadManager
        self.userDefaults = userDefaults
    }

    public func openEpisode(_ episode: Episode) {
        if self.activeEpisode?.id != episode.id {
            self.activeEpisode = episode
            self.currentSegments = []
            self.currentSegmentIndex = 0
            self.restoredPlaybackPosition = nil
        }
        downloadManager?.autoDownloadIfNeeded(for: episode)
        withAnimation(DesignSystem.LiquidGlass.interactiveSpring) {
            self.selectedTab = .player
        }
    }

    public func setSegments(_ segments: [TranscriptSegment]) {
        self.currentSegments = segments
        if let savedPos = restoredPlaybackPosition,
           let idx = segments.lastIndex(where: { $0.seconds <= savedPos }) {
            self.currentSegmentIndex = idx
        } else {
            self.currentSegmentIndex = 0
        }
    }

    public func selectSegment(at index: Int) {
        guard index >= 0 && index < currentSegments.count else { return }
        self.currentSegmentIndex = index
        if let ep = activeEpisode {
            recordPlaybackProgress(for: ep, at: currentSegments[index].seconds)
        }
    }

    public func previousSegment() {
        if currentSegmentIndex > 0 {
            selectSegment(at: currentSegmentIndex - 1)
        }
    }

    public func nextSegment() {
        if currentSegmentIndex + 1 < currentSegments.count {
            selectSegment(at: currentSegmentIndex + 1)
        }
    }

    public func playCurrentSentence(using player: any AudioPlayerProtocol) {
        guard let ep = activeEpisode, let seg = currentSegment else { return }
        let nextSeconds: Double = seg.endSeconds ?? (
            (currentSegmentIndex + 1 < currentSegments.count)
                ? currentSegments[currentSegmentIndex + 1].seconds
                : (seg.seconds + 6.0)
        )
        recordPlaybackProgress(for: ep, at: seg.seconds)
        player.play(segment: seg, in: ep, endTime: nextSeconds)
    }

    public func togglePlayCurrentSentence(using player: any AudioPlayerProtocol) {
        if player.currentEpisode?.id == activeEpisode?.id && player.currentSegment?.id == currentSegment?.id {
            player.togglePlayPause()
        } else {
            playCurrentSentence(using: player)
        }
    }

    public func restoreInitialState(using repository: any EpisodeRepositoryProtocol) async {
        let lastEpisodeId = userDefaults.string(forKey: lastEpisodeKey)
        let savedPosition = userDefaults.double(forKey: lastPositionKey)

        // Case 1: Resume from last played episode and position
        if let epId = lastEpisodeId, let savedEp = try? await repository.fetchEpisode(byId: epId) {
            self.activeEpisode = savedEp
            self.restoredPlaybackPosition = savedPosition > 0 ? savedPosition : nil
            downloadManager?.autoDownloadIfNeeded(for: savedEp)
            return
        }

        // Case 2: Start from latest available episode
        if let episodes = try? await repository.fetchEpisodes(page: 0, pageSize: 1), let latest = episodes.first {
            self.activeEpisode = latest
            self.restoredPlaybackPosition = nil
            downloadManager?.autoDownloadIfNeeded(for: latest)
            return
        }

        // Case 3: Empty state
        self.activeEpisode = nil
        self.restoredPlaybackPosition = nil
    }

    public func recordPlaybackProgress(for episode: Episode, at seconds: Double) {
        userDefaults.set(episode.id, forKey: lastEpisodeKey)
        userDefaults.set(seconds, forKey: lastPositionKey)
    }
}

