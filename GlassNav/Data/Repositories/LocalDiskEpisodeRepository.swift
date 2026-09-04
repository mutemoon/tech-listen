import Foundation
import AVFoundation

/// Concrete repository implementation providing persistent disk caching and local file management.
public actor LocalDiskEpisodeRepository: EpisodeRepositoryProtocol {
    public enum LocalDiskError: LocalizedError {
        case episodeNotFound(String)
        case transcriptNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .episodeNotFound(let id):
                return "Episode with ID '\(id)' not found."
            case .transcriptNotFound(let id):
                return "Transcript file not found for episode '\(id)'."
            }
        }
    }

    private let parser: any TranscriptParserProtocol
    private let storageDirectory: URL
    private let cacheFileName = "episodes_cache.json"

    public init(
        parser: any TranscriptParserProtocol = JSONTranscriptParser(),
        customStorageDirectory: URL? = nil
    ) {
        self.parser = parser

        if let custom = customStorageDirectory {
            self.storageDirectory = custom
        } else if let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.storageDirectory = docURL
        } else {
            self.storageDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        }

        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    private var cacheFileURL: URL {
        storageDirectory.appendingPathComponent(cacheFileName)
    }

    private var downloadsDirectory: URL {
        storageDirectory.appendingPathComponent("downloads", isDirectory: true)
    }

    public func fetchEpisodes() async throws -> [Episode] {
        return try await fetchEpisodes(page: 0, pageSize: 500)
    }

    public func fetchEpisodes(page: Int, pageSize: Int) async throws -> [Episode] {
        let all = try loadCachedEpisodes()
        let startIndex = page * pageSize
        guard startIndex < all.count else { return [] }

        let endIndex = min(startIndex + pageSize, all.count)
        return Array(all[startIndex..<endIndex])
    }

    public func fetchEpisode(byId id: String) async throws -> Episode? {
        let all = try loadCachedEpisodes()
        return all.first { $0.id == id }
    }

    public func fetchTranscript(for episodeId: String) async throws -> [TranscriptSegment] {
        guard let episode = try await fetchEpisode(byId: episodeId) else {
            throw LocalDiskError.episodeNotFound(episodeId)
        }

        let fileName = !episode.transcriptFileName.isEmpty ? episode.transcriptFileName : "\(episodeId)_transcript.json"
        guard let fileURL = resolveFileURL(named: fileName) else {
            throw LocalDiskError.transcriptNotFound(episodeId)
        }

        let data = try Data(contentsOf: fileURL)
        return try parser.parse(from: data)
    }

    public func save(episode: Episode) async throws {
        var all = try loadCachedEpisodes()
        if let idx = all.firstIndex(where: { $0.id == episode.id }) {
            all[idx] = episode
        } else {
            all.append(episode)
        }
        try saveCachedEpisodes(all)
    }

    public func delete(episodeId: String) async throws {
        var all = try loadCachedEpisodes()
        all.removeAll { $0.id == episodeId }
        try saveCachedEpisodes(all)

        let targetAudio = downloadsDirectory.appendingPathComponent("\(episodeId).mp3")
        if FileManager.default.fileExists(atPath: targetAudio.path) {
            try FileManager.default.removeItem(at: targetAudio)
        }
    }

    /// Clears all stored local files and resets download states for all registered episodes.
    public func clearAllStoredContent() async throws {
        var all = try loadCachedEpisodes()

        // 1. Iterate through all registered episodes and delete their associated local files
        for i in 0..<all.count {
            let ep = all[i]
            if let audioName = ep.audioFileName {
                let candidate = downloadsDirectory.appendingPathComponent(audioName)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    try FileManager.default.removeItem(at: candidate)
                }
            }
            let defaultAudio = downloadsDirectory.appendingPathComponent("\(ep.id).mp3")
            if FileManager.default.fileExists(atPath: defaultAudio.path) {
                try FileManager.default.removeItem(at: defaultAudio)
            }

            if !ep.transcriptFileName.isEmpty {
                let transFile = storageDirectory.appendingPathComponent(ep.transcriptFileName)
                if FileManager.default.fileExists(atPath: transFile.path) {
                    try FileManager.default.removeItem(at: transFile)
                }
            }
            if !ep.vttFileName.isEmpty {
                let vttFile = storageDirectory.appendingPathComponent(ep.vttFileName)
                if FileManager.default.fileExists(atPath: vttFile.path) {
                    try FileManager.default.removeItem(at: vttFile)
                }
            }

            all[i] = Episode(
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

        // 2. Persist updated episodes list
        try saveCachedEpisodes(all)

        // 3. Clean up any residual files in downloadsDirectory
        if FileManager.default.fileExists(atPath: downloadsDirectory.path) {
            let files = try FileManager.default.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Internal Storage

    public func loadCachedEpisodes() throws -> [Episode] {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: cacheFileURL)
        return try JSONDecoder().decode([Episode].self, from: data)
    }

    public func saveAllEpisodes(_ episodes: [Episode]) throws {
        try saveCachedEpisodes(episodes)
    }

    private func saveCachedEpisodes(_ episodes: [Episode]) throws {
        let encoded = try JSONEncoder().encode(episodes)
        try encoded.write(to: cacheFileURL, options: .atomic)
    }

    private func resolveFileURL(named name: String) -> URL? {
        let candidates = [
            storageDirectory.appendingPathComponent(name),
            downloadsDirectory.appendingPathComponent(name)
        ]
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
}
