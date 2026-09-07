import SwiftUI

/// Observable ViewModel managing the home episode stream, pull-to-refresh, and download actions.
@Observable
@MainActor
public final class HomeViewModel {
    public var episodes: [Episode] = []
    public var isLoading: Bool = false
    public var isLoadingMore: Bool = false
    public var hasMore: Bool = true

    public var downloadedIds: Set<String> = []
    public var downloadProgressMap: [String: Double] = [:]
    public var downloadStates: [String: DownloadProgressState] = [:]

    public enum RefreshStatus: Equatable, Sendable {
        case success(newCount: Int)
        case upToDate
        case failed
    }

    public var refreshStatus: RefreshStatus? = nil

    private var currentPage: Int = 0

    private let repository: any EpisodeRepositoryProtocol
    private let downloadManager: any DownloadManagerProtocol
    private let configService: any ConfigurationServiceProtocol
    private let feedbackService: any FeedbackServiceProtocol

    nonisolated(unsafe) private var networkObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var dismissToastTask: Task<Void, Never>?
    nonisolated(unsafe) private var clearStorageObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var downloadProgressObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var downloadCompleteObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var downloadCancelObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var downloadFailObserverTask: Task<Void, Never>?

    public init(
        repository: any EpisodeRepositoryProtocol,
        downloadManager: any DownloadManagerProtocol,
        configService: any ConfigurationServiceProtocol,
        feedbackService: any FeedbackServiceProtocol
    ) {
        self.repository = repository
        self.downloadManager = downloadManager
        self.configService = configService
        self.feedbackService = feedbackService

        self.networkObserverTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .didUpdateEpisodesFromNetwork) {
                guard let self = self else { return }
                if let updatedList = notification.object as? [Episode], !updatedList.isEmpty {
                    if self.currentPage == 0 {
                        let count = max(self.episodes.count, self.configService.pageSize)
                        let newTop = Array(updatedList.prefix(count))
                        self.episodes = newTop
                        self.syncDownloadedStates(for: newTop)
                    }
                }
            }
        }

        self.clearStorageObserverTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: Notification.Name("didClearAllLocalStorage")) {
                guard let self = self else { return }
                withAnimation(.snappy(duration: 0.35)) {
                    self.downloadedIds.removeAll()
                    self.downloadProgressMap.removeAll()
                    self.downloadStates.removeAll()
                    for i in 0..<self.episodes.count {
                        self.updateEpisodeState(id: self.episodes[i].id, isDownloaded: false)
                    }
                }
            }
        }

        self.downloadProgressObserverTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .downloadProgressUpdated) {
                guard let self = self, let state = notification.object as? DownloadProgressState else { continue }
                self.downloadStates[state.episodeId] = state
                self.downloadProgressMap[state.episodeId] = state.progress
            }
        }

        self.downloadCompleteObserverTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .downloadDidComplete) {
                guard let self = self, let epId = notification.object as? String else { continue }
                withAnimation(.snappy(duration: 0.35)) {
                    self.downloadProgressMap.removeValue(forKey: epId)
                    self.downloadStates.removeValue(forKey: epId)
                    self.downloadedIds.insert(epId)
                    self.updateEpisodeState(id: epId, isDownloaded: true)
                }
            }
        }

        self.downloadCancelObserverTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .downloadDidCancel) {
                guard let self = self, let epId = notification.object as? String else { continue }
                withAnimation(.snappy(duration: 0.35)) {
                    self.downloadProgressMap.removeValue(forKey: epId)
                    self.downloadStates.removeValue(forKey: epId)
                }
            }
        }

        self.downloadFailObserverTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .downloadDidFail) {
                guard let self = self, let epId = notification.object as? String else { continue }
                withAnimation(.snappy(duration: 0.35)) {
                    self.downloadProgressMap.removeValue(forKey: epId)
                    self.downloadStates.removeValue(forKey: epId)
                }
            }
        }
    }

    deinit {
        networkObserverTask?.cancel()
        dismissToastTask?.cancel()
        clearStorageObserverTask?.cancel()
        downloadProgressObserverTask?.cancel()
        downloadCompleteObserverTask?.cancel()
        downloadCancelObserverTask?.cancel()
        downloadFailObserverTask?.cancel()
    }

    /// Returns episodes filtering out those without subtitles.
    public var filteredEpisodes: [Episode] {
        episodes.filter(\.hasSubtitles)
    }

    /// Loads the initial set of episodes.
    public func loadInitial() async {
        guard episodes.isEmpty else { return }
        isLoading = true
        currentPage = 0
        hasMore = true

        let pageSize = configService.pageSize
        do {
            let initial = try await repository.fetchEpisodes(page: 0, pageSize: pageSize)
            self.episodes = initial
            self.hasMore = initial.count >= pageSize
            syncDownloadedStates(for: initial)
        } catch {
            self.episodes = []
        }

        isLoading = false
    }

    /// Pull-to-refresh implementation to reload the first page from network.
    public func refresh() async {
        let pageSize = configService.pageSize
        let previousLatestId = episodes.first?.id
        let previousLatestNum = episodes.first?.episodeNumber ?? 0

        // Clear any previous banner immediately when starting refresh
        dismissToastTask?.cancel()
        withAnimation(.snappy(duration: 0.2)) {
            self.refreshStatus = nil
        }

        do {
            let refreshed = try await repository.refreshEpisodes()
            self.episodes = refreshed
            self.currentPage = 0
            self.hasMore = refreshed.count >= pageSize
            syncDownloadedStates(for: refreshed)

            // Determine if genuinely newer episodes were retrieved
            let newCount: Int
            if let previousLatestId = previousLatestId,
               let index = refreshed.firstIndex(where: { $0.id == previousLatestId }) {
                newCount = index
            } else if previousLatestNum > 0 {
                newCount = refreshed.filter { $0.episodeNumber > previousLatestNum }.count
            } else {
                newCount = 0
            }

            feedbackService.triggerActionSuccess()
            showRefreshStatus(newCount > 0 ? .success(newCount: newCount) : .upToDate)
        } catch {
            // Keep existing episodes if refresh fails, but alert the user
            feedbackService.triggerActionFailure()
            showRefreshStatus(.failed)
        }
    }

    public func showRefreshStatus(_ status: RefreshStatus) {
        dismissToastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            self.refreshStatus = status
        }

        dismissToastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.refreshStatus = nil
                }
            }
        }
    }

    public func dismissRefreshStatus() {
        dismissToastTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) {
            self.refreshStatus = nil
        }
    }

    /// Explicitly loads the next batch of episodes, supporting continuous infinite scrolling.
    public func loadNextBatch() async {
        guard hasMore, !isLoadingMore else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1
        let pageSize = configService.pageSize

        do {
            let nextBatch = try await repository.fetchEpisodes(page: nextPage, pageSize: pageSize)
            if nextBatch.isEmpty {
                hasMore = false
            } else {
                episodes.append(contentsOf: nextBatch)
                currentPage = nextPage
                hasMore = nextBatch.count >= pageSize
                syncDownloadedStates(for: nextBatch)
                feedbackService.triggerTap()
            }
        } catch {
            hasMore = false
        }

        isLoadingMore = false
    }

    /// Triggers prefetching when user approaches the end of the current visible list.
    public func loadMoreIfNeeded(current episode: Episode) async {
        let currentList = filteredEpisodes
        guard let index = currentList.firstIndex(where: { $0.id == episode.id }) else { return }
        let prefetchThreshold = max(0, currentList.count - 2)
        if index >= prefetchThreshold {
            await loadNextBatch()
        }
    }

    public func isDownloaded(episodeId: String) -> Bool {
        return downloadedIds.contains(episodeId) || downloadManager.isDownloaded(episodeId: episodeId)
    }

    public func downloadProgress(for episodeId: String) -> Double? {
        return downloadStates[episodeId]?.progress ?? downloadProgressMap[episodeId] ?? downloadManager.downloadProgress(for: episodeId)
    }

    public func downloadState(for episodeId: String) -> DownloadProgressState? {
        return downloadStates[episodeId] ?? downloadManager.downloadState(for: episodeId)
    }

    /// Triggers an immediate progressive download with real network downloading and state updates.
    public func triggerDownload(for episode: Episode) async {
        feedbackService.triggerTap()

        withAnimation(.snappy(duration: 0.35)) {
            downloadProgressMap[episode.id] = 0.01
            downloadStates[episode.id] = DownloadProgressState(
                episodeId: episode.id,
                progress: 0.01,
                writtenBytes: 0,
                totalBytes: episode.audioSizeBytes,
                bytesPerSecond: 0,
                estimatedSecondsRemaining: nil
            )
        }

        do {
            try await downloadManager.startDownload(for: episode)
            feedbackService.triggerActionSuccess()
        } catch {
            withAnimation(.snappy(duration: 0.35)) {
                downloadProgressMap.removeValue(forKey: episode.id)
                downloadStates.removeValue(forKey: episode.id)
            }
            feedbackService.triggerActionFailure()
        }
    }

    /// Cancels active download for an episode.
    public func cancelDownload(for episodeId: String) {
        feedbackService.triggerImpact()
        downloadManager.cancelDownload(for: episodeId)

        withAnimation(.snappy(duration: 0.35)) {
            downloadStates.removeValue(forKey: episodeId)
            downloadProgressMap.removeValue(forKey: episodeId)
        }
    }

    /// Immediately removes download state and updates the list item.
    public func removeDownload(for episodeId: String) {
        feedbackService.triggerImpact()

        // 1. Remove physical file via download manager
        do {
            try downloadManager.deleteDownload(for: episodeId)
        } catch {
            feedbackService.triggerActionFailure()
            return
        }

        // 2. Deregister in persistence layer
        Task {
            if let ep = episodes.first(where: { $0.id == episodeId }) {
                let deregistered = Episode(
                    id: ep.id,
                    episodeNumber: ep.episodeNumber,
                    title: ep.title,
                    guest: ep.guest,
                    pubDate: ep.pubDate,
                    audioFileName: nil,
                    audioURL: ep.audioURL,
                    audioSizeBytes: ep.audioSizeBytes,
                    duration: ep.duration,
                    transcriptFileName: ep.transcriptFileName,
                    vttFileName: ep.vttFileName,
                    totalSegments: ep.totalSegments,
                    isDownloaded: false
                )
                try? await repository.save(episode: deregistered)
            }
        }

        withAnimation(.snappy(duration: 0.35)) {
            downloadedIds.remove(episodeId)
            downloadProgressMap.removeValue(forKey: episodeId)
            downloadStates.removeValue(forKey: episodeId)
            updateEpisodeState(id: episodeId, isDownloaded: false)
        }
    }

    private func syncDownloadedStates(for list: [Episode]) {
        for ep in list {
            let physicallyDownloaded = downloadManager.isDownloaded(episodeId: ep.id)
            if physicallyDownloaded {
                downloadedIds.insert(ep.id)
                downloadStates.removeValue(forKey: ep.id)
                downloadProgressMap.removeValue(forKey: ep.id)
                if !ep.isDownloaded {
                    updateEpisodeState(id: ep.id, isDownloaded: true)
                }
            } else if let activeState = downloadManager.downloadState(for: ep.id) {
                // Re-hydration: In-progress download found in service
                downloadedIds.remove(ep.id)
                downloadStates[ep.id] = activeState
                downloadProgressMap[ep.id] = activeState.progress
            } else {
                downloadedIds.remove(ep.id)
                downloadStates.removeValue(forKey: ep.id)
                downloadProgressMap.removeValue(forKey: ep.id)
                if ep.isDownloaded {
                    updateEpisodeState(id: ep.id, isDownloaded: false)
                }
            }
        }
    }

    private func updateEpisodeState(id: String, isDownloaded: Bool) {
        if let idx = episodes.firstIndex(where: { $0.id == id }) {
            let ep = episodes[idx]
            episodes[idx] = Episode(
                id: ep.id,
                episodeNumber: ep.episodeNumber,
                title: ep.title,
                guest: ep.guest,
                pubDate: ep.pubDate,
                audioFileName: ep.audioFileName,
                audioURL: ep.audioURL,
                audioSizeBytes: ep.audioSizeBytes,
                duration: ep.duration,
                transcriptFileName: ep.transcriptFileName,
                vttFileName: ep.vttFileName,
                totalSegments: ep.totalSegments,
                isDownloaded: isDownloaded
            )
        }
    }
}
