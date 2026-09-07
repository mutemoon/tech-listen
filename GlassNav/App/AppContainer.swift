import SwiftUI

/// Concrete production container binding real persistent storage and services.
@MainActor
public final class ProductionContainer: AppContainerProtocol {
    public let appState: any AppStateProtocol
    public let configurationService: any ConfigurationServiceProtocol
    public let feedbackService: any FeedbackServiceProtocol
    public let persistenceService: any EpisodeRepositoryProtocol
    public let cacheService: any CacheServiceProtocol
    public let requestService: any RequestServiceProtocol
    public let episodeRepository: any EpisodeRepositoryProtocol
    public let downloadManager: any DownloadManagerProtocol
    public let audioPlayer: any AudioPlayerProtocol

    public init(
        appState: (any AppStateProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        feedbackService: (any FeedbackServiceProtocol)? = nil,
        persistenceService: (any EpisodeRepositoryProtocol)? = nil,
        cacheService: (any CacheServiceProtocol)? = nil,
        requestService: (any RequestServiceProtocol)? = nil,
        episodeRepository: (any EpisodeRepositoryProtocol)? = nil,
        downloadManager: (any DownloadManagerProtocol)? = nil,
        audioPlayer: (any AudioPlayerProtocol)? = nil
    ) {
        let req = requestService ?? URLSessionRequestService()
        let config = configurationService ?? AppConfigurationService()
        let persistence = persistenceService ?? LocalDiskEpisodeRepository()
        let repo = episodeRepository ?? RemoteRSSFeedEpisodeRepository(
            localDiskRepo: persistence,
            requestService: req
        )
        let dl = downloadManager ?? StandardDownloadManager(episodeRepository: repo)
        self.appState = appState ?? StandardAppState(downloadManager: dl)
        self.configurationService = config
        self.feedbackService = feedbackService ?? HapticFeedbackService(config: config)
        self.persistenceService = persistence
        self.cacheService = cacheService ?? MemoryDiskCacheService()
        self.requestService = req
        self.episodeRepository = repo
        self.downloadManager = dl
        self.audioPlayer = audioPlayer ?? StandardAudioPlayer()
    }
}

// MARK: - SwiftUI Environment Injection

@MainActor
private struct AppContainerKey: @preconcurrency EnvironmentKey {
    static let defaultValue: any AppContainerProtocol = ProductionContainer()
}

extension EnvironmentValues {
    public var appContainer: any AppContainerProtocol {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
