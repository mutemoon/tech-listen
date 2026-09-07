import Foundation

/// High-precision WebVTT parser conforming to TranscriptParserProtocol.
/// Parses native WebVTT cues and stitches split caption fragments into grammatically
/// complete, natural sentences with millisecond-accurate start and end boundaries.
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

    private struct RawCue {
        let startSeconds: Double
        let endSeconds: Double
        let speaker: String
        let text: String
    }

    private static let commonAbbreviations: Set<String> = [
        "u.s.", "e.g.", "i.e.", "vs.", "etc.", "dr.", "mr.", "mrs.", "ms.", "inc.", "co.", "no.", "st.", "prof."
    ]

    public init() {}

    public func parse(from data: Data) throws -> [TranscriptSegment] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw VTTParserError.invalidEncoding
        }

        // 1. Extract raw cues from WebVTT
        let rawCues = try extractRawCues(from: text)
        guard !rawCues.isEmpty else { return [] }

        // 2. Stitch cues into grammatically complete sentences
        return stitchCuesIntoSentences(rawCues)
    }

    // MARK: - Private Parsing Pipeline

    private func extractRawCues(from text: String) throws -> [RawCue] {
        var cues: [RawCue] = []
        let lines = text.components(separatedBy: .newlines)

        var currentStartSeconds: Double?
        var currentEndSeconds: Double?
        var currentSpeaker = ""
        var currentLines: [String] = []

        func flushCue() {
            guard let start = currentStartSeconds, let end = currentEndSeconds else { return }
            let fullText = currentLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullText.isEmpty {
                cues.append(
                    RawCue(
                        startSeconds: start,
                        endSeconds: end,
                        speaker: currentSpeaker,
                        text: fullText
                    )
                )
            }
            currentStartSeconds = nil
            currentEndSeconds = nil
            currentSpeaker = ""
            currentLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("WEBVTT") || trimmed.hasPrefix("NOTE") {
                continue
            }

            // Cue timing line: "00:00:00.740 --> 00:00:05.100" (possibly followed by cue settings)
            if trimmed.contains("-->") {
                flushCue()
                let parts = trimmed.components(separatedBy: "-->")
                if parts.count >= 2 {
                    let startPart = parts[0].trimmingCharacters(in: .whitespaces)
                    let endFull = parts[1].trimmingCharacters(in: .whitespaces)
                    // The end timestamp might be followed by settings like line:0% position:50%
                    let endPart = endFull.components(separatedBy: .whitespaces).first ?? endFull

                    currentStartSeconds = try parseTimestampToSeconds(startPart)
                    currentEndSeconds = try parseTimestampToSeconds(endPart)
                }
                continue
            }

            // Dialogue content line
            if currentStartSeconds != nil {
                var cleanLine = trimmed
                // Handle voice tags: <v Speaker>Text
                if cleanLine.hasPrefix("<v ") && cleanLine.contains(">") {
                    let scanner = Scanner(string: cleanLine)
                    _ = scanner.scanString("<v ")
                    if let parsedSpeaker = scanner.scanUpToString(">") {
                        currentSpeaker = parsedSpeaker
                    }
                    _ = scanner.scanString(">")
                    cleanLine = scanner.scanUpToString("\n") ?? ""
                }
                // Strip all remaining HTML/VTT tags e.g. <b>, </i>, <c.color>
                cleanLine = cleanLine.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)

                if !cleanLine.isEmpty {
                    currentLines.append(cleanLine)
                }
            }
        }

        flushCue()
        return cues
    }

    private func stitchCuesIntoSentences(_ cues: [RawCue]) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        segments.reserveCapacity(cues.count / 2)

        var sentenceStartSeconds: Double?
        var sentenceEndSeconds: Double?
        var sentenceSpeaker: String = ""
        var bufferedTexts: [String] = []

        func flushSentence() {
            guard let start = sentenceStartSeconds, let end = sentenceEndSeconds, !bufferedTexts.isEmpty else { return }
            let fullSentence = bufferedTexts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullSentence.isEmpty {
                let id = "seg-\(segments.count + 1)"
                let timestamp = formatSecondsToTimestamp(start)
                segments.append(
                    TranscriptSegment(
                        id: id,
                        speaker: sentenceSpeaker,
                        timestamp: timestamp,
                        seconds: start,
                        endSeconds: end,
                        text: fullSentence
                    )
                )
            }
            sentenceStartSeconds = nil
            sentenceEndSeconds = nil
            sentenceSpeaker = ""
            bufferedTexts.removeAll()
        }

        for (index, cue) in cues.enumerated() {
            if sentenceStartSeconds == nil {
                sentenceStartSeconds = cue.startSeconds
                sentenceSpeaker = cue.speaker
            }
            sentenceEndSeconds = cue.endSeconds
            bufferedTexts.append(cue.text)

            // Determine if current cue terminates a complete sentence
            let isTerminal = isSentenceTerminal(cue.text)
            let accumulatedDuration = cue.endSeconds - (sentenceStartSeconds ?? cue.startSeconds)

            // Check if there is a significant silence pause before the next cue (> 1.2 seconds)
            let hasSignificantPause: Bool
            if index + 1 < cues.count {
                let gap = cues[index + 1].startSeconds - cue.endSeconds
                hasSignificantPause = gap > 1.2
            } else {
                hasSignificantPause = true
            }

            // 最小断句条件最少 1.0 秒，最大断句条件最多 5.0 秒
            let minDuration: Double = 1.0
            let maxDuration: Double = 5.0

            let reachedMaxDuration = accumulatedDuration >= maxDuration
            let reachedTerminalWithMinDuration = isTerminal && accumulatedDuration >= minDuration
            let reachedPauseWithMinDuration = hasSignificantPause && accumulatedDuration >= minDuration

            if reachedMaxDuration || reachedTerminalWithMinDuration || reachedPauseWithMinDuration {
                flushSentence()
            }
        }

        flushSentence()
        return segments
    }

    private func isSentenceTerminal(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Must end with ., ?, or ! (or quotes like .", ?", !")
        let endsWithPunctuation = trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
            || trimmed.hasSuffix(".\"") || trimmed.hasSuffix("?\"") || trimmed.hasSuffix("!\"")
            || trimmed.hasSuffix(".'") || trimmed.hasSuffix("?'") || trimmed.hasSuffix("!'")

        guard endsWithPunctuation else { return false }

        // Check if last word is a known abbreviation (e.g. "U.S.")
        let lastWord = trimmed.components(separatedBy: .whitespaces).last?.lowercased() ?? ""
        if Self.commonAbbreviations.contains(lastWord) {
            return false
        }

        return true
    }

    private func parseTimestampToSeconds(_ timestamp: String) throws -> Double {
        let clean = timestamp.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
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

    private func formatSecondsToTimestamp(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
