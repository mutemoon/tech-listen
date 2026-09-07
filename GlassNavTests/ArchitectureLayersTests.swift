import Testing
import Foundation
@testable import GlassNav

@Suite("Architecture Layers & Modular Swappability Tests")
struct ArchitectureLayersTests {

    // 1. Mock persistence layer conforming to EpisodeRepositoryProtocol to test modular swappability
    final class MockPersistenceRepository: EpisodeRepositoryProtocol, @unchecked Sendable {
        var episodes: [Episode] = []
        var transcripts: [String: [TranscriptSegment]] = [:]
        var clearCalled: Bool = false

        func fetchEpisodes() async throws -> [Episode] { episodes }
        func fetchEpisodes(page: Int, pageSize: Int) async throws -> [Episode] { episodes }
        func fetchEpisode(byId id: String) async throws -> Episode? { episodes.first { $0.id == id } }
        func fetchTranscript(for episodeId: String) async throws -> [TranscriptSegment] {
            transcripts[episodeId] ?? []
        }
        func save(episode: Episode) async throws { episodes.append(episode) }
        func delete(episodeId: String) async throws { episodes.removeAll { $0.id == episodeId } }
        func clearAllStoredContent() async throws {
            clearCalled = true
            episodes.removeAll()
            transcripts.removeAll()
        }
        func saveAllEpisodes(_ episodes: [Episode]) async throws {
            self.episodes = episodes
        }
        func saveTranscript(_ segments: [TranscriptSegment], for episodeId: String) async throws {
            self.transcripts[episodeId] = segments
        }
    }

    @Test("RemoteRSSFeedEpisodeRepository works with swapped mock persistence layer")
    func testRepositorySwappability() async throws {
        let mockPersistence = MockPersistenceRepository()
        mockPersistence.episodes = [
            Episode(
                id: "mock_1",
                episodeNumber: 1,
                title: "Mock Title",
                guest: "Tester",
                pubDate: "2026-09-06",
                duration: 120
            )
        ]

        let remoteRepo = RemoteRSSFeedEpisodeRepository(
            localDiskRepo: mockPersistence
        )

        let loaded = try await remoteRepo.fetchEpisodes(page: 0, pageSize: 10)
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == "mock_1")
        #expect(loaded.first?.title == "Mock Title")
    }

    @Test("AppContainerProtocol provides all 6 standard architectural layers")
    @MainActor
    func testAppContainerLayers() {
        let container = ProductionContainer()

        // 1. 全局状态层
        #expect(container.appState != nil)
        // 2. 配置层
        #expect(container.configurationService != nil)
        // 3. 反馈层
        #expect(container.feedbackService != nil)
        // 4. 持久层
        #expect(container.persistenceService != nil)
        // 5. 缓存层
        #expect(container.cacheService != nil)
        // 6. 请求层
        #expect(container.requestService != nil)
    }

    @Test("ConfigurationService resetToDefaults restores language and haptic defaults")
    @MainActor
    func testConfigurationReset() {
        let config = AppConfigurationService()
        config.language = .english
        config.hapticEnabled = false

        #expect(config.language == .english)
        #expect(config.hapticEnabled == false)

        config.resetToDefaults()

        #expect(config.language == .chinese)
        #expect(config.hapticEnabled == true)
    }
}
