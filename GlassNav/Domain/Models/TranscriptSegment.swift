import Foundation

/// Represents an individual time-aligned sentence or dialog segment.
public struct TranscriptSegment: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let speaker: String
    public let timestamp: String
    public let seconds: Double
    public let text: String

    public init(
        id: String = UUID().uuidString,
        speaker: String,
        timestamp: String,
        seconds: Double,
        text: String
    ) {
        self.id = id
        self.speaker = speaker
        self.timestamp = timestamp
        self.seconds = seconds
        self.text = text
    }
}
