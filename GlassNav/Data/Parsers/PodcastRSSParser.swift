import Foundation

/// Clean, standard RSS feed parser parsing podcast XML into Episode domain models.
public final class PodcastRSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var parsedEpisodes: [Episode] = []
    private var inItem: Bool = false
    private var currentElement: String = ""

    private var titleBuffer: String = ""
    private var pubDateBuffer: String = ""
    private var durationBuffer: String = ""
    private var descBuffer: String = ""
    private var enclosureUrl: String = ""
    private var enclosureLen: Int64 = 0

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
            pubDateBuffer = ""
            durationBuffer = ""
            descBuffer = ""
            enclosureUrl = ""
            enclosureLen = 0
        } else if inItem && elementName == "enclosure" {
            enclosureUrl = attributeDict["url"] ?? ""
            enclosureLen = Int64(attributeDict["length"] ?? "") ?? 0
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title":
            titleBuffer += string
        case "pubDate":
            pubDateBuffer += string
        case "itunes:duration":
            durationBuffer += string
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
        guard elementName == "item" else { return }
        inItem = false

        // 1. Guard: Only retain episodes that have online transcripts
        guard descBuffer.contains("-transcript") else { return }

        // 2. Parse Episode Number (e.g. "#501")
        guard let epRange = titleBuffer.range(of: #"#\d+"#, options: .regularExpression) else { return }
        let epNumStr = String(titleBuffer[epRange].dropFirst())
        guard let epNum = Int(epNumStr) else { return }

        // 2. Clean Title
        var cleanTitle = titleBuffer
        if let prefixRange = cleanTitle.range(of: #"^#\d+\s*[-–—:]\s*"#, options: .regularExpression) {
            cleanTitle.removeSubrange(prefixRange)
        }
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#038;", with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")

        // 3. Guest (Happy Path: "Guest: Topic" format)
        let guest: String
        if cleanTitle.contains(":") {
            guest = cleanTitle.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
        } else {
            guest = ""
        }

        // 4. Format Publication Date (RFC822 -> YYYY-MM-DD)
        let rawDate = pubDateBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedDate: String
        if let date = Self.rfc822Formatter.date(from: rawDate) {
            formattedDate = Self.isoDateFormatter.string(from: date)
        } else {
            formattedDate = rawDate
        }

        // 5. Parse Duration (HH:mm:ss / mm:ss / seconds)
        let duration = parseDuration(durationBuffer.trimmingCharacters(in: .whitespacesAndNewlines))

        // 6. Segments (Happy Path: ~18s per segment)
        let totalSegments = duration > 0 ? Int(duration / 18.0) : 0

        parsedEpisodes.append(
            Episode(
                id: "ep\(epNum)",
                episodeNumber: epNum,
                title: cleanTitle,
                guest: guest,
                pubDate: formattedDate,
                audioFileName: nil,
                audioURL: enclosureUrl.isEmpty ? nil : enclosureUrl,
                audioSizeBytes: enclosureLen,
                duration: duration,
                transcriptFileName: "",
                vttFileName: "",
                totalSegments: totalSegments,
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
