import Foundation

/// Defines the repository contract for retrieving and persisting episodes.
/// Implementations can be swapped between LocalDisk, SwiftData, or Network.
public protocol EpisodeRepositoryProtocol: Sendable {
    /// Retrieve all available episodes.
    func fetchEpisodes() async throws -> [Episode]

    /// Retrieve paginated episodes for infinite scroll history loading.
    func fetchEpisodes(page: Int, pageSize: Int) async throws -> [Episode]

    /// Fetch a single episode by its unique identifier.
    func fetchEpisode(byId id: String) async throws -> Episode?

    /// Fetch the full sentence-level transcript segments for an episode.
    func fetchTranscript(for episodeId: String) async throws -> [TranscriptSegment]

    /// Fetch the full sentence-level transcript segments for an episode entity directly.
    func fetchTranscript(for episode: Episode) async throws -> [TranscriptSegment]

    /// Save or update an episode entity.
    func save(episode: Episode) async throws

    /// Delete an episode and its associated local resources.
    func delete(episodeId: String) async throws

    /// Refresh episodes from network or primary source.
    func refreshEpisodes() async throws -> [Episode]

    /// Clears all stored local files and reset registered download states through the persistence layer.
    func clearAllStoredContent() async throws

    /// Save a list of episodes to the persistence store.
    func saveAllEpisodes(_ episodes: [Episode]) async throws

    /// Save sentence-level transcript segments for an episode.
    func saveTranscript(_ segments: [TranscriptSegment], for episodeId: String) async throws
}

extension EpisodeRepositoryProtocol {
    public func refreshEpisodes() async throws -> [Episode] {
        try await fetchEpisodes(page: 0, pageSize: 20)
    }

    public func fetchTranscript(for episode: Episode) async throws -> [TranscriptSegment] {
        try await fetchTranscript(for: episode.id)
    }

    public func saveAllEpisodes(_ episodes: [Episode]) async throws {
        for ep in episodes {
            try await save(episode: ep)
        }
    }

    public func saveTranscript(_ segments: [TranscriptSegment], for episodeId: String) async throws {}
}
