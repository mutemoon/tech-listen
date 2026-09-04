import Foundation

/// Real implementation of DownloadManagerProtocol handling local storage and file management.
@MainActor
public final class StandardDownloadManager: DownloadManagerProtocol {
    private let fileManager = FileManager.default
    private let downloadDirectory: URL
    private let coordinator = DownloadCoordinator()
    private let episodeRepository: (any EpisodeRepositoryProtocol)?
    private var activeProgressStates: [String: DownloadProgressState] = [:]

    public var activeDownloads: [String: DownloadProgressState] {
        activeProgressStates
    }

    public init(episodeRepository: (any EpisodeRepositoryProtocol)? = nil) {
        self.episodeRepository = episodeRepository
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.downloadDirectory = docs.appendingPathComponent("downloads", isDirectory: true)
        } else {
            self.downloadDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        try? fileManager.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
    }

    public func isDownloaded(episodeId: String) -> Bool {
        let target = downloadDirectory.appendingPathComponent("\(episodeId).mp3")
        if fileManager.fileExists(atPath: target.path),
           let attrs = try? fileManager.attributesOfItem(atPath: target.path),
           let size = attrs[.size] as? Int64, size > 0 {
            return true
        }
        return false
    }

    public func downloadProgress(for episodeId: String) -> Double? {
        return activeProgressStates[episodeId]?.progress
    }

    public func downloadState(for episodeId: String) -> DownloadProgressState? {
        return activeProgressStates[episodeId]
    }

    public func startDownload(
        for episode: Episode,
        onProgress: (@MainActor @Sendable (DownloadProgressState) -> Void)? = nil
    ) async throws {
        guard let urlString = episode.audioURL, let remoteURL = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let target = downloadDirectory.appendingPathComponent("\(episode.id).mp3")

        do {
            try await coordinator.startDownload(
                episodeId: episode.id,
                remoteURL: remoteURL,
                destinationURL: target,
                totalExpected: episode.audioSizeBytes
            ) { [weak self] state in
                guard let self = self else { return }
                self.activeProgressStates[episode.id] = state
                onProgress?(state)
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: state
                )
            }
            activeProgressStates.removeValue(forKey: episode.id)

            // Auto-persist downloaded state to repository so storage is closed-loop
            if let repo = self.episodeRepository {
                let updatedEpisode = Episode(
                    id: episode.id,
                    episodeNumber: episode.episodeNumber,
                    title: episode.title,
                    guest: episode.guest,
                    pubDate: episode.pubDate,
                    audioFileName: "\(episode.id).mp3",
                    audioURL: episode.audioURL,
                    audioSizeBytes: episode.audioSizeBytes,
                    duration: episode.duration,
                    transcriptFileName: episode.transcriptFileName,
                    vttFileName: episode.vttFileName,
                    totalSegments: episode.totalSegments,
                    isDownloaded: true
                )
                try? await repo.save(episode: updatedEpisode)
            }

            NotificationCenter.default.post(name: .downloadDidComplete, object: episode.id)
            NotificationCenter.default.post(name: Notification.Name("didChangeCacheStorage"), object: nil)
        } catch {
            activeProgressStates.removeValue(forKey: episode.id)
            NotificationCenter.default.post(name: .downloadDidFail, object: episode.id)
            throw error
        }
    }

    public func cancelDownload(for episodeId: String) {
        coordinator.cancelDownload(episodeId: episodeId)
        activeProgressStates.removeValue(forKey: episodeId)
        NotificationCenter.default.post(name: .downloadDidCancel, object: episodeId)
    }

    public func deleteDownload(for episodeId: String) throws {
        cancelDownload(for: episodeId)
        let target = downloadDirectory.appendingPathComponent("\(episodeId).mp3")
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        activeProgressStates.removeValue(forKey: episodeId)
        NotificationCenter.default.post(name: Notification.Name("didChangeCacheStorage"), object: nil)
    }

    public func deleteAllDownloads() throws {
        for (epId, _) in activeProgressStates {
            coordinator.cancelDownload(episodeId: epId)
            NotificationCenter.default.post(name: .downloadDidCancel, object: epId)
        }
        activeProgressStates.removeAll()

        if fileManager.fileExists(atPath: downloadDirectory.path),
           let files = try? fileManager.contentsOfDirectory(at: downloadDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
        NotificationCenter.default.post(name: Notification.Name("didChangeCacheStorage"), object: nil)
    }

    public func fetchDownloadedEpisodes() async throws -> [Episode] {
        return []
    }
}

// MARK: - Download Coordinator

private final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct ActiveTask {
        let episodeId: String
        let totalExpected: Int64
        let destinationURL: URL
        let progressHandler: (@MainActor @Sendable (DownloadProgressState) -> Void)?
        let continuation: CheckedContinuation<Void, Error>
        var lastUpdateDate: Date
        var lastWrittenBytes: Int64
        var smoothedSpeed: Double
    }

    private let lock = NSLock()
    private var tasks: [Int: ActiveTask] = [:]
    private var tasksByEpisodeId: [String: URLSessionDownloadTask] = [:]
    private let fileManager = FileManager.default
    private var session: URLSession!

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 900
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func startDownload(
        episodeId: String,
        remoteURL: URL,
        destinationURL: URL,
        totalExpected: Int64,
        onProgress: (@MainActor @Sendable (DownloadProgressState) -> Void)?
    ) async throws {
        cancelDownload(episodeId: episodeId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let task = session.downloadTask(with: remoteURL)
            let context = ActiveTask(
                episodeId: episodeId,
                totalExpected: totalExpected,
                destinationURL: destinationURL,
                progressHandler: onProgress,
                continuation: continuation,
                lastUpdateDate: Date(),
                lastWrittenBytes: 0,
                smoothedSpeed: 0
            )

            lock.lock()
            tasks[task.taskIdentifier] = context
            tasksByEpisodeId[episodeId] = task
            lock.unlock()

            // Report initial state
            let initial = DownloadProgressState(
                episodeId: episodeId,
                progress: 0.0,
                writtenBytes: 0,
                totalBytes: totalExpected,
                bytesPerSecond: 0,
                estimatedSecondsRemaining: nil
            )
            Task { @MainActor in
                onProgress?(initial)
            }

            task.resume()
        }
    }

    func cancelDownload(episodeId: String) {
        lock.lock()
        let task = tasksByEpisodeId.removeValue(forKey: episodeId)
        if let t = task {
            tasks.removeValue(forKey: t.taskIdentifier)
        }
        lock.unlock()
        task?.cancel()
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        guard var active = tasks[downloadTask.taskIdentifier] else {
            lock.unlock()
            return
        }

        let now = Date()
        let timeInterval = now.timeIntervalSince(active.lastUpdateDate)
        let isDone = totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite

        // Throttle UI callbacks to at most once per 200ms
        guard timeInterval >= 0.2 || isDone else {
            lock.unlock()
            return
        }

        let totalExpected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : active.totalExpected
        let bytesDelta = totalBytesWritten - active.lastWrittenBytes
        let currentSpeed = timeInterval > 0 ? Double(bytesDelta) / timeInterval : 0
        let smoothedSpeed = active.smoothedSpeed == 0 ? currentSpeed : (0.65 * currentSpeed + 0.35 * active.smoothedSpeed)

        active.lastUpdateDate = now
        active.lastWrittenBytes = totalBytesWritten
        active.smoothedSpeed = smoothedSpeed
        tasks[downloadTask.taskIdentifier] = active
        let handler = active.progressHandler
        let episodeId = active.episodeId
        lock.unlock()

        let progress = totalExpected > 0 ? min(1.0, Double(totalBytesWritten) / Double(totalExpected)) : 0.0
        let remainingBytes = max(0, totalExpected - totalBytesWritten)
        let estimatedSecs = smoothedSpeed > 0 && remainingBytes > 0 ? Double(remainingBytes) / smoothedSpeed : nil

        let state = DownloadProgressState(
            episodeId: episodeId,
            progress: progress,
            writtenBytes: totalBytesWritten,
            totalBytes: totalExpected,
            bytesPerSecond: smoothedSpeed,
            estimatedSecondsRemaining: estimatedSecs
        )

        Task { @MainActor in
            handler?(state)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        let active = tasks[downloadTask.taskIdentifier]
        lock.unlock()

        guard let active = active else { return }

        do {
            if fileManager.fileExists(atPath: active.destinationURL.path) {
                try? fileManager.removeItem(at: active.destinationURL)
            }
            try fileManager.moveItem(at: location, to: active.destinationURL)
        } catch {
            lock.lock()
            tasks.removeValue(forKey: downloadTask.taskIdentifier)
            tasksByEpisodeId.removeValue(forKey: active.episodeId)
            lock.unlock()
            active.continuation.resume(throwing: error)
            return
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let active = tasks.removeValue(forKey: task.taskIdentifier)
        if let id = active?.episodeId {
            tasksByEpisodeId.removeValue(forKey: id)
        }
        lock.unlock()

        guard let active = active else { return }

        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                active.continuation.resume(throwing: CancellationError())
            } else {
                active.continuation.resume(throwing: error)
            }
        } else {
            active.continuation.resume()
        }
    }
}
