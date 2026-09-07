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
    public let transcriptURL: String?
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
        transcriptURL: String? = nil,
        totalSegments: Int = 0,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.guest = guest
        self.pubDate = pubDate
        self.audioFileName = audioFileName
        self.audioURL = audioURL
        self.audioSizeBytes = audioSizeBytes
        self.duration = duration
        self.transcriptFileName = transcriptFileName
        self.vttFileName = vttFileName
        self.transcriptURL = transcriptURL
        self.totalSegments = totalSegments
        self.isDownloaded = isDownloaded
    }

    enum CodingKeys: String, CodingKey {
        case id, episodeNumber, title, guest, pubDate
        case audioFileName, audioURL, audioSizeBytes, duration
        case transcriptFileName, vttFileName, transcriptURL
        case totalSegments, isDownloaded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.episodeNumber = try container.decode(Int.self, forKey: .episodeNumber)
        let rawTitle = try container.decode(String.self, forKey: .title)
        self.title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.guest = try container.decode(String.self, forKey: .guest)
        self.pubDate = try container.decode(String.self, forKey: .pubDate)
        self.audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
        self.audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
        self.audioSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .audioSizeBytes) ?? 0
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        self.transcriptFileName = try container.decodeIfPresent(String.self, forKey: .transcriptFileName) ?? ""
        self.vttFileName = try container.decodeIfPresent(String.self, forKey: .vttFileName) ?? ""
        self.transcriptURL = try container.decodeIfPresent(String.self, forKey: .transcriptURL)
        self.totalSegments = try container.decodeIfPresent(Int.self, forKey: .totalSegments) ?? 0
        self.isDownloaded = try container.decodeIfPresent(Bool.self, forKey: .isDownloaded) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(episodeNumber, forKey: .episodeNumber)
        try container.encode(title, forKey: .title)
        try container.encode(guest, forKey: .guest)
        try container.encode(pubDate, forKey: .pubDate)
        try container.encodeIfPresent(audioFileName, forKey: .audioFileName)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(audioSizeBytes, forKey: .audioSizeBytes)
        try container.encode(duration, forKey: .duration)
        try container.encode(transcriptFileName, forKey: .transcriptFileName)
        try container.encode(vttFileName, forKey: .vttFileName)
        try container.encodeIfPresent(transcriptURL, forKey: .transcriptURL)
        try container.encode(totalSegments, forKey: .totalSegments)
        try container.encode(isDownloaded, forKey: .isDownloaded)
    }

    /// Resolved author or speaker name for display.
    public var displayAuthor: String {
        guest.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Indicates whether this episode has available sentence-level subtitles.
    public var hasSubtitles: Bool {
        totalSegments > 0 || transcriptURL != nil || !transcriptFileName.isEmpty || !vttFileName.isEmpty
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
