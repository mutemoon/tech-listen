import Foundation

/// Abstraction for parsing raw transcript and subtitle data.
/// Implementations can be swapped between JSON, WebVTT, SRT, or Whisper format.
public protocol TranscriptParserProtocol: Sendable {
    /// Parses raw transcript data into a sequence of time-aligned segments.
    func parse(from data: Data) throws -> [TranscriptSegment]
}
