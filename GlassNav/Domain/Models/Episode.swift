import Foundation

/// Represents a podcast episode in the domain layer.
public struct Episode: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let episodeNumber: Int
    public let title: String
    public let guest: String
    public let pubDate: String
    public let audioFileName: String?
    public let audioURL: String?
    public let audioSizeBytes: Int64
    public let duration: TimeInterval
    public let transcriptFileName: String
    public let vttFileName: String
    public let totalSegments: Int
    public let isDownloaded: Bool

    public init(
        id: String,
        episodeNumber: Int,
        title: String,
        guest: String,
        pubDate: String,
        audioFileName: String? = nil,
        audioURL: String? = nil,
        audioSizeBytes: Int64 = 0,
        duration: TimeInterval = 0,
        transcriptFileName: String = "",
        vttFileName: String = "",
        totalSegments: Int = 0,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.title = title
        self.guest = guest
        self.pubDate = pubDate
        self.audioFileName = audioFileName
        self.audioURL = audioURL
        self.audioSizeBytes = audioSizeBytes
        self.duration = duration
        self.transcriptFileName = transcriptFileName
        self.vttFileName = vttFileName
        self.totalSegments = totalSegments
        self.isDownloaded = isDownloaded
    }

    /// Indicates whether this episode has available sentence-level subtitles.
    public var hasSubtitles: Bool {
        totalSegments > 0
    }

    /// Formats the duration into a human-readable string (e.g. "5小时15分", "45分钟", or "30秒").
    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        guard totalSeconds > 0 else { return "--" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
}
