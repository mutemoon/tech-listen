import Foundation
import AVFoundation

public extension Notification.Name {
    static let didUpdateEpisodesFromNetwork = Notification.Name("didUpdateEpisodesFromNetwork")
}

/// Live network repository fetching real episodes directly from the podcast RSS feed,
/// with instant local cache fallback and local media resolution.
public actor RemoteRSSFeedEpisodeRepository: EpisodeRepositoryProtocol {
    public static let defaultFeedURL = URL(string: "https://lexfridman.com/feed/podcast/")!

    private let feedURL: URL
    private let rssParser: PodcastRSSParser
    private let localDiskRepo: LocalDiskEpisodeRepository
    private let session: URLSession

    private var inMemoryEpisodes: [Episode]?
    private var isRefreshingNetwork: Bool = false
    private var lastNetworkFetchDate: Date?

    public init(
        feedURL: URL = RemoteRSSFeedEpisodeRepository.defaultFeedURL,
        rssParser: PodcastRSSParser = PodcastRSSParser(),
        localDiskRepo: LocalDiskEpisodeRepository = LocalDiskEpisodeRepository(),
        session: URLSession = .shared
    ) {
        self.feedURL = feedURL
        self.rssParser = rssParser
        self.localDiskRepo = localDiskRepo
        self.session = session
    }

    public func fetchEpisodes() async throws -> [Episode] {
        return try await fetchEpisodes(page: 0, pageSize: 20)
    }

    public func fetchEpisodes(page: Int, pageSize: Int) async throws -> [Episode] {
        let all = try await loadEpisodes(triggerNetworkIfStale: page == 0)
        let startIndex = page * pageSize
        guard startIndex < all.count else { return [] }
        let endIndex = min(startIndex + pageSize, all.count)
        return Array(all[startIndex..<endIndex])
    }

    public enum FeedError: LocalizedError {
        case networkError(Error)
        case invalidResponse(Int)
        case emptyData

        public var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return error.localizedDescription
            case .invalidResponse(let code):
                return "Server error: HTTP \(code)"
            case .emptyData:
                return "Empty feed response"
            }
        }
    }

    /// Explicitly forces a live network fetch from the podcast RSS feed.
    public func refreshEpisodes() async throws -> [Episode] {
        let live = try await fetchLiveFeedFromNetworkThrows()
        return Array(live.prefix(20))
    }

    public func fetchEpisode(byId id: String) async throws -> Episode? {
        let all = try await loadEpisodes(triggerNetworkIfStale: false)
        return all.first { $0.id == id }
    }

    public func fetchTranscript(for episodeId: String) async throws -> [TranscriptSegment] {
        return try await localDiskRepo.fetchTranscript(for: episodeId)
    }

    public func save(episode: Episode) async throws {
        try await localDiskRepo.save(episode: episode)
        if var current = inMemoryEpisodes, let idx = current.firstIndex(where: { $0.id == episode.id }) {
            current[idx] = episode
            self.inMemoryEpisodes = current
        }
    }

    public func delete(episodeId: String) async throws {
        try await localDiskRepo.delete(episodeId: episodeId)
        if var current = inMemoryEpisodes, let idx = current.firstIndex(where: { $0.id == episodeId }) {
            let ep = current[idx]
            current[idx] = Episode(
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
            self.inMemoryEpisodes = current
        }
    }

    public func clearAllStoredContent() async throws {
        try await localDiskRepo.clearAllStoredContent()

        if let current = inMemoryEpisodes {
            self.inMemoryEpisodes = current.map { ep in
                Episode(
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
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("didClearAllLocalStorage"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("didChangeCacheStorage"), object: nil)
        }
    }

    // MARK: - Live Network & Cache Pipeline

    /// Returns current episodes immediately from memory/disk cache,
    /// and triggers live network update if needed.
    private func loadEpisodes(triggerNetworkIfStale: Bool) async throws -> [Episode] {
        if let current = inMemoryEpisodes, !current.isEmpty {
            let needsNetwork = triggerNetworkIfStale && shouldFetchLiveNetwork()
            if needsNetwork {
                Task { [weak self] in
                    _ = try? await self?.fetchLiveFeedFromNetworkThrows()
                }
            }
            return current
        }

        // 1. Initial immediate seed from local disk repository (0ms startup)
        let initialLocal = try await localDiskRepo.fetchEpisodes(page: 0, pageSize: 500)
        if !initialLocal.isEmpty {
            self.inMemoryEpisodes = initialLocal
            if triggerNetworkIfStale {
                Task { [weak self] in
                    _ = try? await self?.fetchLiveFeedFromNetworkThrows()
                }
            }
            return initialLocal
        }

        // 2. If local disk is completely empty, fetch live feed from network
        let networkEpisodes = try await fetchLiveFeedFromNetworkThrows()
        return networkEpisodes
    }

    private func shouldFetchLiveNetwork() -> Bool {
        guard let last = lastNetworkFetchDate else { return true }
        // Refresh every 10 minutes in background
        return Date().timeIntervalSince(last) > 600
    }

    /// Makes real HTTP network request to the live RSS feed, parses items,
    /// and updates memory & persistent disk cache.
    @discardableResult
    public func fetchLiveFeedFromNetwork() async throws -> [Episode] {
        return try await fetchLiveFeedFromNetworkThrows()
    }

    public func fetchLiveFeedFromNetworkThrows() async throws -> [Episode] {
        if isRefreshingNetwork {
            if let current = inMemoryEpisodes, !current.isEmpty {
                return current
            }
        }
        isRefreshingNetwork = true
        defer { isRefreshingNetwork = false }

        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedError.networkError(error)
        }

        guard let httpResp = response as? HTTPURLResponse else {
            throw FeedError.emptyData
        }

        guard httpResp.statusCode == 200 else {
            throw FeedError.invalidResponse(httpResp.statusCode)
        }

        // Parse live XML in Swift
        let rawList = rssParser.parse(data: data)
        guard !rawList.isEmpty else {
            throw FeedError.emptyData
        }

        // Check local download status for episodes
        var merged: [Episode] = []
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let downloadsDir = docs?.appendingPathComponent("downloads", isDirectory: true)

        for ep in rawList {
            let audioFile = "\(ep.id).mp3"
            let isDownloaded: Bool
            if let target = downloadsDir?.appendingPathComponent(audioFile),
               FileManager.default.fileExists(atPath: target.path) {
                isDownloaded = true
            } else {
                isDownloaded = false
            }

            merged.append(
                Episode(
                    id: ep.id,
                    episodeNumber: ep.episodeNumber,
                    title: ep.title,
                    guest: ep.guest,
                    pubDate: ep.pubDate,
                    audioFileName: isDownloaded ? audioFile : nil,
                    audioURL: ep.audioURL,
                    audioSizeBytes: ep.audioSizeBytes,
                    duration: ep.duration,
                    transcriptFileName: ep.transcriptFileName,
                    vttFileName: ep.vttFileName,
                    totalSegments: ep.totalSegments,
                    isDownloaded: isDownloaded
                )
            )
        }

        // Persist to local disk repository
        try await localDiskRepo.saveAllEpisodes(merged)

        self.inMemoryEpisodes = merged
        self.lastNetworkFetchDate = Date()

        // Post notification on main actor for listeners
        await MainActor.run {
            NotificationCenter.default.post(name: .didUpdateEpisodesFromNetwork, object: merged)
        }

        return merged
    }
}
