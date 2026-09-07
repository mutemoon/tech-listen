import Foundation

/// Clean, standard RSS feed parser parsing podcast XML into Episode domain models.
public final class PodcastRSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var parsedEpisodes: [Episode] = []
    private var inItem: Bool = false
    private var currentElement: String = ""

    private var channelAuthorBuffer: String = ""
    private var channelHostBuffer: String = ""
    private var currentPersonRole: String = ""

    private var titleBuffer: String = ""
    private var itunesTitleBuffer: String = ""
    private var episodeNumberBuffer: String = ""
    private var itunesEpisodeBuffer: String = ""
    private var authorBuffer: String = ""
    private var itunesAuthorBuffer: String = ""
    private var pubDateBuffer: String = ""
    private var durationBuffer: String = ""
    private var itunesDurationBuffer: String = ""
    private var descBuffer: String = ""
    private var enclosureUrl: String = ""
    private var enclosureLen: Int64 = 0
    private var transcriptUrl: String = ""

    private static let rfc822Formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return df
    }()

    private static let isoDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    public override init() {
        super.init()
    }

    /// Parses raw RSS XML data into an array of Episode domain entities.
    public func parse(data: Data) -> [Episode] {
        parsedEpisodes.removeAll()
        inItem = false
        currentElement = ""
        channelAuthorBuffer = ""
        channelHostBuffer = ""
        currentPersonRole = ""

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.parse()

        return parsedEpisodes
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            titleBuffer = ""
            itunesTitleBuffer = ""
            episodeNumberBuffer = ""
            itunesEpisodeBuffer = ""
            authorBuffer = ""
            itunesAuthorBuffer = ""
            pubDateBuffer = ""
            durationBuffer = ""
            itunesDurationBuffer = ""
            descBuffer = ""
            enclosureUrl = ""
            enclosureLen = 0
            transcriptUrl = ""
        } else if elementName == "podcast:person" || elementName == "person" {
            currentPersonRole = attributeDict["role"] ?? ""
        } else if inItem && elementName == "enclosure" {
            enclosureUrl = attributeDict["url"] ?? ""
            enclosureLen = Int64(attributeDict["length"] ?? "") ?? 0
        } else if inItem && (elementName == "podcast:transcript" || elementName == "transcript") {
            let url = attributeDict["url"] ?? ""
            let type = attributeDict["type"] ?? ""
            if type.contains("vtt") || url.hasSuffix(".vtt") {
                transcriptUrl = url
            }
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !inItem {
            switch currentElement {
            case "itunes:author", "author":
                channelAuthorBuffer += string
            case "podcast:person", "person":
                if currentPersonRole.isEmpty || currentPersonRole.lowercased() == "host" {
                    channelHostBuffer += string
                }
            default:
                break
            }
            return
        }

        switch currentElement {
        case "title":
            titleBuffer += string
        case "itunes:title":
            itunesTitleBuffer += string
        case "episode":
            episodeNumberBuffer += string
        case "itunes:episode":
            itunesEpisodeBuffer += string
        case "author":
            authorBuffer += string
        case "itunes:author":
            itunesAuthorBuffer += string
        case "podcast:person", "person":
            if currentPersonRole.isEmpty || currentPersonRole.lowercased() == "host" {
                authorBuffer += string
            }
        case "pubDate":
            pubDateBuffer += string
        case "duration":
            durationBuffer += string
        case "itunes:duration":
            itunesDurationBuffer += string
        case "description":
            descBuffer += string
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem else { return }
        if currentElement == "description", let str = String(data: CDATABlock, encoding: .utf8) {
            descBuffer += str
        }
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "podcast:person" || elementName == "person" {
            currentPersonRole = ""
        }

        guard elementName == "item" else { return }
        inItem = false

        // 1. Guard: Only retain episodes that have an audio enclosure URL
        guard !enclosureUrl.isEmpty else { return }

        // Select non-empty title source (prefer standard <title>, fallback to <itunes:title>)
        let resolvedTitleBuffer = !titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? titleBuffer
            : itunesTitleBuffer

        // 2. Parse Episode Number
        let epNum: Int
        let rawEp = (!itunesEpisodeBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? itunesEpisodeBuffer : episodeNumberBuffer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let num = Int(rawEp) {
            epNum = num
        } else if let epRange = resolvedTitleBuffer.range(of: #"#\d+"#, options: .regularExpression) {
            epNum = Int(resolvedTitleBuffer[epRange].dropFirst()) ?? (parsedEpisodes.count + 1)
        } else {
            epNum = parsedEpisodes.count + 1
        }

        // 3. Clean Title
        var cleanTitle = resolvedTitleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let prefixRange = cleanTitle.range(of: #"^#\d+\s*[-–—:]\s*"#, options: .regularExpression) {
            cleanTitle.removeSubrange(prefixRange)
        }
        cleanTitle = cleanTitle
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8216;", with: "'")
            .replacingOccurrences(of: "&#8220;", with: "\"")
            .replacingOccurrences(of: "&#8221;", with: "\"")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Host / Guest
        let itemAuthor = (!itunesAuthorBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? itunesAuthorBuffer : authorBuffer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedChannelHost = channelHostBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedChannelAuthor = channelAuthorBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        let guest: String
        if !itemAuthor.isEmpty {
            guest = itemAuthor
        } else if !resolvedChannelHost.isEmpty {
            guest = resolvedChannelHost
        } else if !resolvedChannelAuthor.isEmpty {
            guest = resolvedChannelAuthor
        } else {
            guest = ""
        }

        // 5. Format Publication Date (RFC822 -> YYYY-MM-DD)
        let rawDate = pubDateBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedDate: String
        if let date = Self.rfc822Formatter.date(from: rawDate) {
            formattedDate = Self.isoDateFormatter.string(from: date)
        } else {
            formattedDate = rawDate
        }

        // 6. Parse Duration (HH:mm:ss / mm:ss / seconds)
        let rawDuration = !itunesDurationBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? itunesDurationBuffer
            : durationBuffer
        let duration = parseDuration(rawDuration.trimmingCharacters(in: .whitespacesAndNewlines))

        parsedEpisodes.append(
            Episode(
                id: "podnews-\(epNum)",
                episodeNumber: epNum,
                title: cleanTitle,
                guest: guest,
                pubDate: formattedDate,
                audioFileName: nil,
                audioURL: enclosureUrl,
                audioSizeBytes: enclosureLen,
                duration: duration,
                transcriptFileName: "",
                vttFileName: "",
                transcriptURL: transcriptUrl.isEmpty ? nil : transcriptUrl,
                totalSegments: 0,
                isDownloaded: false
            )
        )
    }

    private func parseDuration(_ raw: String) -> TimeInterval {
        guard !raw.isEmpty else { return 0 }
        let parts = raw.components(separatedBy: ":").compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }
}
