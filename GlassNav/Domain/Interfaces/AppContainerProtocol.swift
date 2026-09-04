import Foundation

/// Defines the dependency injection container contract for the application.
/// Exposes the four core application layers: Configuration, Feedback, Persistence, and Cache.
@MainActor
public protocol AppContainerProtocol: Sendable {
    var configurationService: any ConfigurationServiceProtocol { get }
    var feedbackService: any FeedbackServiceProtocol { get }
    var episodeRepository: any EpisodeRepositoryProtocol { get }
    var cacheService: any CacheServiceProtocol { get }
    var downloadManager: any DownloadManagerProtocol { get }
    var audioPlayer: any AudioPlayerProtocol { get }
}
