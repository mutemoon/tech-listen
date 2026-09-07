import Foundation

/// Represents detailed real-time download metrics for an episode.
public struct DownloadProgressState: Sendable, Equatable {
    public let episodeId: String
    public let progress: Double // 0.0 to 1.0
    public let writtenBytes: Int64
    public let totalBytes: Int64
    public let bytesPerSecond: Double
    public let estimatedSecondsRemaining: TimeInterval?

    public init(
        episodeId: String,
        progress: Double,
        writtenBytes: Int64,
        totalBytes: Int64,
        bytesPerSecond: Double,
        estimatedSecondsRemaining: TimeInterval?
    ) {
        self.episodeId = episodeId
        self.progress = progress
        self.writtenBytes = writtenBytes
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
    }

    public var remainingBytes: Int64 {
        max(0, totalBytes - writtenBytes)
    }
}

/// Abstraction for managing episode downloads.
@MainActor
public protocol DownloadManagerProtocol: AnyObject, Sendable {
    /// Returns all active in-flight download states keyed by episode ID.
    var activeDownloads: [String: DownloadProgressState] { get }

    /// Returns true if the episode media is locally stored.
    func isDownloaded(episodeId: String) -> Bool

    /// Returns active progress fraction from 0.0 to 1.0 if downloading.
    func downloadProgress(for episodeId: String) -> Double?

    /// Returns detailed real-time download progress state if downloading.
    func downloadState(for episodeId: String) -> DownloadProgressState?

    /// Starts downloading the audio file for the episode with optional real-time progress callback.
    func startDownload(
        for episode: Episode,
        onProgress: (@MainActor @Sendable (DownloadProgressState) -> Void)?
    ) async throws

    /// Starts downloading the audio file for the episode.
    func startDownload(for episode: Episode) async throws

    /// Cancels active download for an episode.
    func cancelDownload(for episodeId: String)

    /// Deletes the downloaded audio file for the episode.
    func deleteDownload(for episodeId: String) throws

    /// Cancels and deletes all active and completed downloads.
    func deleteAllDownloads() throws

    /// Automatically starts downloading the episode in background if not already downloaded or downloading.
    func autoDownloadIfNeeded(for episode: Episode)
}

extension DownloadManagerProtocol {
    public var activeDownloads: [String: DownloadProgressState] {
        [:]
    }

    public func startDownload(for episode: Episode) async throws {
        try await startDownload(for: episode, onProgress: nil)
    }

    public func downloadState(for episodeId: String) -> DownloadProgressState? {
        nil
    }

    public func cancelDownload(for episodeId: String) {}

    public func autoDownloadIfNeeded(for episode: Episode) {
        guard !isDownloaded(episodeId: episode.id), downloadState(for: episode.id) == nil else { return }
        Task {
            try? await startDownload(for: episode)
        }
    }
}

// MARK: - Download Notification Events

extension Notification.Name {
    /// Posted when download progress advances for an episode. Object is `DownloadProgressState`.
    public static let downloadProgressUpdated = Notification.Name("downloadProgressUpdated")
    /// Posted when an episode successfully finishes downloading. Object is `String` (episode ID).
    public static let downloadDidComplete = Notification.Name("downloadDidComplete")
    /// Posted when an episode download fails. Object is `String` (episode ID).
    public static let downloadDidFail = Notification.Name("downloadDidFail")
    /// Posted when an episode download is explicitly cancelled. Object is `String` (episode ID).
    public static let downloadDidCancel = Notification.Name("downloadDidCancel")
}
