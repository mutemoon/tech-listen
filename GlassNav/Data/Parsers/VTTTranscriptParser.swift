import Foundation

/// Parses WebVTT (.vtt) format transcript files conforming to TranscriptParserProtocol.
public struct VTTTranscriptParser: TranscriptParserProtocol {
    public enum VTTParserError: LocalizedError {
        case invalidEncoding
        case invalidTimestamp(String)

        public var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Failed to decode VTT data as UTF-8 text."
            case .invalidTimestamp(let raw):
                return "Invalid VTT timestamp: '\(raw)'."
            }
        }
    }

    public init() {}

    public func parse(from data: Data) throws -> [TranscriptSegment] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw VTTParserError.invalidEncoding
        }

        var segments: [TranscriptSegment] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentStartTimestamp = ""
        var currentSeconds: Double = 0.0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("WEBVTT") {
                continue
            }

            // Match timestamp arrow: 00:03:23.000 --> 00:03:26.000
            if trimmed.contains("-->") {
                let parts = trimmed.components(separatedBy: "-->")
                if let startStr = parts.first?.trimmingCharacters(in: .whitespaces) {
                    currentStartTimestamp = startStr
                    currentSeconds = try parseTimestampToSeconds(startStr)
                }
                continue
            }

            // Match dialogue line, optionally with voice tag: <v Speaker>Text
            if !currentStartTimestamp.isEmpty {
                var speaker = ""
                var dialogText = trimmed

                if trimmed.hasPrefix("<v ") && trimmed.contains(">") {
                    let scanner = Scanner(string: trimmed)
                    _ = scanner.scanString("<v ")
                    if let parsedSpeaker = scanner.scanUpToString(">") {
                        speaker = parsedSpeaker
                    }
                    _ = scanner.scanString(">")
                    dialogText = scanner.scanUpToString("\n") ?? ""
                }

                segments.append(
                    TranscriptSegment(
                        id: "\(segments.count)",
                        speaker: speaker,
                        timestamp: currentStartTimestamp,
                        seconds: currentSeconds,
                        text: dialogText
                    )
                )
                currentStartTimestamp = ""
            }
        }

        return segments
    }

    private func parseTimestampToSeconds(_ timestamp: String) throws -> Double {
        let clean = timestamp.replacingOccurrences(of: ",", with: ".")
        let components = clean.components(separatedBy: ":")
        guard components.count >= 2 else {
            throw VTTParserError.invalidTimestamp(timestamp)
        }

        if components.count == 3 {
            guard let h = Double(components[0]),
                  let m = Double(components[1]),
                  let s = Double(components[2]) else {
                throw VTTParserError.invalidTimestamp(timestamp)
            }
            return h * 3600 + m * 60 + s
        } else {
            guard let m = Double(components[0]),
                  let s = Double(components[1]) else {
                throw VTTParserError.invalidTimestamp(timestamp)
            }
            return m * 60 + s
        }
    }
}
