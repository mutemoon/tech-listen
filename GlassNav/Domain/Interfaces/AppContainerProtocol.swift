import Foundation

/// Defines the dependency injection container contract for the application.
/// Exposes the core application layers: Global State, Configuration, Feedback, Request, Persistence, and Cache.
@MainActor
public protocol AppContainerProtocol: Sendable {
    // MARK: - 6 Core Architecture Layers
    var appState: any AppStateProtocol { get }
    var configurationService: any ConfigurationServiceProtocol { get }
    var feedbackService: any FeedbackServiceProtocol { get }
    var persistenceService: any EpisodeRepositoryProtocol { get }
    var cacheService: any CacheServiceProtocol { get }
    var requestService: any RequestServiceProtocol { get }

    // MARK: - Coordinators
    var episodeRepository: any EpisodeRepositoryProtocol { get }
    var downloadManager: any DownloadManagerProtocol { get }
    var audioPlayer: any AudioPlayerProtocol { get }
}
