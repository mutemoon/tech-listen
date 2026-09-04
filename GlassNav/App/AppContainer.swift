import SwiftUI

/// Concrete production container binding real persistent storage and services.
@MainActor
public final class ProductionContainer: AppContainerProtocol {
    public let configurationService: any ConfigurationServiceProtocol
    public let feedbackService: any FeedbackServiceProtocol
    public let episodeRepository: any EpisodeRepositoryProtocol
    public let cacheService: any CacheServiceProtocol
    public let downloadManager: any DownloadManagerProtocol
    public let audioPlayer: any AudioPlayerProtocol

    public init(
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        feedbackService: (any FeedbackServiceProtocol)? = nil,
        episodeRepository: (any EpisodeRepositoryProtocol)? = nil,
        cacheService: (any CacheServiceProtocol)? = nil,
        downloadManager: (any DownloadManagerProtocol)? = nil,
        audioPlayer: (any AudioPlayerProtocol)? = nil
    ) {
        let config = configurationService ?? AppConfigurationService()
        let repo = episodeRepository ?? RemoteRSSFeedEpisodeRepository()
        self.configurationService = config
        self.feedbackService = feedbackService ?? HapticFeedbackService(config: config)
        self.episodeRepository = repo
        self.cacheService = cacheService ?? MemoryDiskCacheService()
        self.downloadManager = downloadManager ?? StandardDownloadManager(episodeRepository: repo)
        self.audioPlayer = audioPlayer ?? StandardAudioPlayer()
    }
}

/// Testing and preview container binding standard repositories and services.
@MainActor
public final class PreviewContainer: AppContainerProtocol {
    public let configurationService: any ConfigurationServiceProtocol
    public let feedbackService: any FeedbackServiceProtocol
    public let episodeRepository: any EpisodeRepositoryProtocol
    public let cacheService: any CacheServiceProtocol
    public let downloadManager: any DownloadManagerProtocol
    public let audioPlayer: any AudioPlayerProtocol

    public init(
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        feedbackService: (any FeedbackServiceProtocol)? = nil,
        episodeRepository: (any EpisodeRepositoryProtocol)? = nil,
        cacheService: (any CacheServiceProtocol)? = nil,
        downloadManager: (any DownloadManagerProtocol)? = nil,
        audioPlayer: (any AudioPlayerProtocol)? = nil
    ) {
        let config = configurationService ?? AppConfigurationService()
        let repo = episodeRepository ?? RemoteRSSFeedEpisodeRepository()
        self.configurationService = config
        self.feedbackService = feedbackService ?? HapticFeedbackService(config: config)
        self.episodeRepository = repo
        self.cacheService = cacheService ?? MemoryDiskCacheService()
        self.downloadManager = downloadManager ?? StandardDownloadManager(episodeRepository: repo)
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
