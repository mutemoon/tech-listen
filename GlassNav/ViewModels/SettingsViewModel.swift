import SwiftUI

/// Observable ViewModel driving the Settings screen and dynamic parameters.
@Observable
@MainActor
public final class SettingsViewModel {
    private let configService: any ConfigurationServiceProtocol
    private let feedbackService: any FeedbackServiceProtocol
    private let cacheService: any CacheServiceProtocol
    private let episodeRepository: any EpisodeRepositoryProtocol
    private let downloadManager: any DownloadManagerProtocol

    public var cacheSizeDisplay: String = ""

    public init(
        configService: any ConfigurationServiceProtocol,
        feedbackService: any FeedbackServiceProtocol,
        cacheService: any CacheServiceProtocol,
        episodeRepository: any EpisodeRepositoryProtocol,
        downloadManager: any DownloadManagerProtocol
    ) {
        self.configService = configService
        self.feedbackService = feedbackService
        self.cacheService = cacheService
        self.episodeRepository = episodeRepository
        self.downloadManager = downloadManager
        self.cacheSizeDisplay = cacheService.formattedCacheSize()
    }

    public var language: Language {
        get { configService.language }
        set {
            configService.language = newValue
            feedbackService.triggerTap()
        }
    }

    public var hapticEnabled: Bool {
        get { configService.hapticEnabled }
        set {
            configService.hapticEnabled = newValue
            if newValue {
                feedbackService.triggerActionSuccess()
            }
        }
    }

    public func clearCache() {
        Task {
            do {
                // 1. Let the persistence layer clear all registered content, audio/transcript files, and reset states
                try await episodeRepository.clearAllStoredContent()

                // 2. Let download manager cancel any active tasks and clean up download tracking
                try downloadManager.deleteAllDownloads()

                // 3. Clear memory cache
                cacheService.clearAll()

                // 4. Refresh displayed size and give haptic feedback
                cacheSizeDisplay = cacheService.formattedCacheSize()
                feedbackService.triggerActionSuccess()
            } catch {
                feedbackService.triggerActionFailure()
            }
        }
    }

    public func refreshCacheSize() {
        cacheSizeDisplay = cacheService.formattedCacheSize()
    }

    public func resetDefaults() {
        configService.resetToDefaults()
        feedbackService.triggerActionSuccess()
    }
}
