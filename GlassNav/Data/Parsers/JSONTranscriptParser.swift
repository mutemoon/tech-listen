import Foundation

/// Parses structured JSON transcript files conforming to TranscriptParserProtocol.
public struct JSONTranscriptParser: TranscriptParserProtocol {
    private struct RootPayload: Decodable {
        let episode_id: String?
        let segments: [SegmentPayload]
    }

    private struct SegmentPayload: Decodable {
        let id: String?
        let speaker: String
        let timestamp: String
        let seconds: Double
        let text: String
    }

    public init() {}

    public func parse(from data: Data) throws -> [TranscriptSegment] {
        let decoder = JSONDecoder()
        
        let payloads: [SegmentPayload]
        do {
            payloads = try decoder.decode(RootPayload.self, from: data).segments
        } catch {
            payloads = try decoder.decode([SegmentPayload].self, from: data)
        }
        
        return payloads.enumerated().map { index, item in
            TranscriptSegment(
                id: item.id ?? "\(index)",
                speaker: item.speaker,
                timestamp: item.timestamp,
                seconds: item.seconds,
                text: item.text
            )
        }
    }
}
