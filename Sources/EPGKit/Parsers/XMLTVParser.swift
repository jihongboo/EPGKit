import Foundation

/// A parser for the XMLTV EPG format.
///
/// Parses XML data conforming to the XMLTV specification into ``EPGData``.
///
/// ## Supported XMLTV Elements
///
/// ### Root element
/// - `<tv>` attributes: `date`, `source-info-url`, `source-info-name`, `source-data-url`,
///   `generator-info-name`, `generator-info-url`
///
/// ### Channel elements
/// - `<channel id="...">`
///   - `<display-name lang="...">`
///   - `<icon src="..." width="..." height="...">` (multiple allowed)
///   - `<url>` (multiple allowed)
///
/// ### Programme elements
/// - `<programme start="..." stop="..." channel="..." pdc-start="..." vps-start="..."
///   showview="..." videoplus="..." clumpidx="...">`
///   - `<title lang="...">` (one or more)
///   - `<sub-title lang="...">`
///   - `<desc lang="...">`
///   - `<credits>` (with `director`, `actor role="..." guest="yes|no"`, `writer`, etc.)
///   - `<date>`
///   - `<category lang="...">`
///   - `<keyword lang="...">`
///   - `<language lang="...">`
///   - `<orig-language lang="...">`
///   - `<length units="...">`
///   - `<icon src="..." width="..." height="...">` (multiple allowed)
///   - `<url>` (multiple allowed)
///   - `<country lang="...">` (multiple allowed)
///   - `<episode-num system="...">`
///   - `<video>` (with `colour`, `aspect`, `quality`, `present`)
///   - `<audio>` (with `present`, `stereo`)
///   - `<previously-shown start="..." channel="...">`
///   - `<premiere lang="...">`
///   - `<last-chance lang="...">`
///   - `<new>`
///   - `<live>`
///   - `<subtitles type="...">` (with `language`)
///   - `<rating system="...">` (with `value`, `icon`)
///   - `<star-rating system="...">` (with `value`, `icon`)
///   - `<review type="..." source="..." reviewer="..." lang="...">`
///   - `<image type="..." size="..." orient="..." system="...">`
///
/// ## Date Format
///
/// XMLTV dates use the format `YYYYMMDDHHmmss +HHMM`, for example:
/// - `20240101120000 +0000` — 2024-01-01 12:00:00 UTC
/// - `20240101120000 +0100` — 2024-01-01 12:00:00 CET
public struct XMLTVParser: EPGParser {

    public init() {}

    public func parse(data: Data) throws -> EPGData {
        guard !data.isEmpty else { throw EPGError.emptyData }

        let delegate = XMLTVParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        parser.parse()

        // Return any domain error set before abortParsing() was called first.
        if let error = delegate.parseError {
            throw error
        }

        if let parserError = parser.parserError {
            throw EPGError.xmlParsingFailed(reason: parserError.localizedDescription)
        }

        return EPGData(
            channels: delegate.channels,
            programmes: delegate.programmes,
            sourceInfo: delegate.sourceInfo
        )
    }
}

// MARK: - XMLTVParserDelegate

/// SAX-style XML parser delegate for XMLTV data (internal use only).
private final class XMLTVParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: - Results

    private(set) var channels: [Channel] = []
    private(set) var programmes: [Programme] = []
    private(set) var sourceInfo: SourceInfo?
    private(set) var parseError: EPGError?

    // MARK: - Parser State

    private var currentElement: String = ""
    private var currentText: String = ""
    private var currentAttributes: [String: String] = [:]

    // Channel builder state
    private var currentChannelID: String?
    private var currentDisplayNames: [LocalizedString] = []
    private var currentChannelIcons: [Icon] = []
    private var currentChannelURLs: [EPGUrl] = []

    // Programme builder state
    private var currentProgramme: ProgrammeBuilder?

    // credits builder state
    private var insideCredits = false
    private var creditsBuilder: CreditsBuilder?
    private var actorBuilder: ActorBuilder?

    // rating / star-rating builder state
    private var insideRating = false
    private var insideStarRating = false
    private var ratingBuilder: RatingBuilder?
    private var starRatingBuilder: StarRatingBuilder?

    // video / audio builder state
    private var insideVideo = false
    private var insideAudio = false
    private var videoBuilder: VideoBuilder?
    private var audioBuilder: AudioBuilder?

    // subtitles builder state
    private var insideSubtitles = false
    private var subtitleBuilder: SubtitleBuilder?

    // review builder state
    private var insideReview = false
    private var reviewBuilder: ReviewBuilder?

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        currentAttributes = attributeDict

        switch elementName {
        case "tv":
            sourceInfo = parseSourceInfo(from: attributeDict)

        case "channel":
            guard let id = attributeDict["id"], !id.isEmpty else {
                parseError = .missingRequiredField(field: "channel.id")
                parser.abortParsing()
                return
            }
            currentChannelID = id
            currentDisplayNames = []
            currentChannelIcons = []
            currentChannelURLs = []

        case "programme":
            guard let channelID = attributeDict["channel"], !channelID.isEmpty else {
                parseError = .missingRequiredField(field: "programme.channel")
                parser.abortParsing()
                return
            }
            guard let startStr = attributeDict["start"], !startStr.isEmpty else {
                parseError = .missingRequiredField(field: "programme.start")
                parser.abortParsing()
                return
            }
            guard let start = parseXMLTVDate(startStr) else {
                parseError = .invalidDateFormat(value: startStr)
                parser.abortParsing()
                return
            }
            let stop: Date?
            if let stopStr = attributeDict["stop"] {
                guard let parsed = parseXMLTVDate(stopStr) else {
                    parseError = .invalidDateFormat(value: stopStr)
                    parser.abortParsing()
                    return
                }
                stop = parsed
            } else {
                stop = nil
            }
            let builder = ProgrammeBuilder(channelID: channelID, start: start, stop: stop)
            builder.pdcStart = attributeDict["pdc-start"].flatMap { parseXMLTVDate($0) }
            builder.vpsStart = attributeDict["vps-start"].flatMap { parseXMLTVDate($0) }
            builder.showview = attributeDict["showview"]
            builder.videoplus = attributeDict["videoplus"]
            builder.clumpIndex = attributeDict["clumpidx"]
            currentProgramme = builder

        case "credits":
            insideCredits = true
            creditsBuilder = CreditsBuilder()

        case "rating":
            insideRating = true
            ratingBuilder = RatingBuilder(system: attributeDict["system"])

        case "star-rating":
            insideStarRating = true
            starRatingBuilder = StarRatingBuilder(system: attributeDict["system"])

        case "video":
            insideVideo = true
            videoBuilder = VideoBuilder()

        case "audio":
            insideAudio = true
            audioBuilder = AudioBuilder()

        case "subtitles":
            insideSubtitles = true
            subtitleBuilder = SubtitleBuilder(type: attributeDict["type"])

        case "review":
            insideReview = true
            reviewBuilder = ReviewBuilder(
                type: attributeDict["type"],
                source: attributeDict["source"],
                reviewer: attributeDict["reviewer"],
                language: attributeDict["lang"]
            )

        case "previously-shown":
            if currentProgramme != nil {
                currentProgramme?.previouslyShown = PreviouslyShown(
                    start: attributeDict["start"].flatMap { parseXMLTVDate($0) },
                    channel: attributeDict["channel"]
                )
            }

        case "new":
            currentProgramme?.isNew = true

        case "live":
            currentProgramme?.isLive = true

        case "actor":
            if insideCredits {
                actorBuilder = ActorBuilder(
                    role: attributeDict["role"],
                    guest: attributeDict["guest"] == "yes"
                )
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
        // Accumulate actor name from direct text content only (not from child elements).
        // currentElement == "actor" means we are in the direct text content of <actor>,
        // before any child element resets currentElement.
        if currentElement == "actor" {
            actorBuilder?.nameBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {

        // MARK: Channel end
        case "channel":
            if let id = currentChannelID {
                channels.append(Channel(
                    id: id,
                    displayNames: currentDisplayNames,
                    icons: currentChannelIcons,
                    urls: currentChannelURLs
                ))
            }
            currentChannelID = nil

        case "display-name":
            if currentChannelID != nil {
                currentDisplayNames.append(
                    LocalizedString(value: text, language: currentAttributes["lang"])
                )
            }

        case "url":
            guard let epgUrl = URL(string: text).map({ EPGUrl(url: $0, system: currentAttributes["system"]) }) else { break }
            if actorBuilder != nil {
                actorBuilder?.url = epgUrl
            } else if currentChannelID != nil {
                currentChannelURLs.append(epgUrl)
            } else {
                currentProgramme?.urls.append(epgUrl)
            }

        case "icon":
            if let icon = parseIcon(from: currentAttributes) {
                if currentChannelID != nil {
                    currentChannelIcons.append(icon)
                } else if insideRating {
                    ratingBuilder?.icon = icon
                } else if insideStarRating {
                    starRatingBuilder?.icon = icon
                } else if currentProgramme != nil {
                    currentProgramme?.icons.append(icon)
                }
            }

        // MARK: Programme end
        case "programme":
            if let builder = currentProgramme {
                programmes.append(builder.build())
            }
            currentProgramme = nil

        case "title":
            currentProgramme?.titles.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "sub-title":
            currentProgramme?.subTitles.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "desc":
            currentProgramme?.descriptions.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "category":
            currentProgramme?.categories.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "keyword":
            currentProgramme?.keywords.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "date":
            currentProgramme?.date = text

        case "country":
            currentProgramme?.countries.append(
                LocalizedString(value: text, language: currentAttributes["lang"])
            )

        case "language":
            if insideSubtitles {
                subtitleBuilder?.language = LocalizedString(value: text, language: currentAttributes["lang"])
            } else {
                currentProgramme?.language = LocalizedString(value: text, language: currentAttributes["lang"])
            }

        case "orig-language":
            currentProgramme?.originalLanguage = LocalizedString(value: text, language: currentAttributes["lang"])

        case "length":
            if let value = Int(text) {
                currentProgramme?.length = Length(value: value, units: currentAttributes["units"] ?? "minutes")
            }

        case "episode-num":
            currentProgramme?.episodeNumbers.append(
                EpisodeNumber(value: text, system: currentAttributes["system"])
            )

        case "last-chance":
            currentProgramme?.lastChance = LocalizedString(value: text, language: currentAttributes["lang"])

        case "premiere":
            currentProgramme?.premiere = LocalizedString(value: text, language: currentAttributes["lang"])

        case "image":
            if let image = parseImage(from: currentAttributes, text: text) {
                if actorBuilder != nil {
                    actorBuilder?.image = image
                } else {
                    currentProgramme?.images.append(image)
                }
            }

        // MARK: Credits
        case "credits":
            insideCredits = false
            if let builder = creditsBuilder {
                currentProgramme?.credits = builder.build()
            }
            creditsBuilder = nil

        case "director":
            if insideCredits { creditsBuilder?.directors.append(text) }

        case "actor":
            if insideCredits, let builder = actorBuilder {
                creditsBuilder?.actors.append(builder.build())
                actorBuilder = nil
            }

        case "writer":
            if insideCredits { creditsBuilder?.writers.append(text) }

        case "adapter":
            if insideCredits { creditsBuilder?.adapters.append(text) }

        case "producer":
            if insideCredits { creditsBuilder?.producers.append(text) }

        case "composer":
            if insideCredits { creditsBuilder?.composers.append(text) }

        case "editor":
            if insideCredits { creditsBuilder?.editors.append(text) }

        case "presenter":
            if insideCredits { creditsBuilder?.presenters.append(text) }

        case "commentator":
            if insideCredits { creditsBuilder?.commentators.append(text) }

        case "guest":
            if insideCredits { creditsBuilder?.guests.append(text) }

        // MARK: Rating
        case "rating":
            insideRating = false
            if let builder = ratingBuilder {
                currentProgramme?.ratings.append(builder.build())
            }
            ratingBuilder = nil

        case "star-rating":
            insideStarRating = false
            if let builder = starRatingBuilder {
                currentProgramme?.starRatings.append(builder.build())
            }
            starRatingBuilder = nil

        case "value":
            if insideRating { ratingBuilder?.value = text }
            else if insideStarRating { starRatingBuilder?.value = text }

        // MARK: Video
        case "video":
            insideVideo = false
            currentProgramme?.video = videoBuilder?.build()
            videoBuilder = nil

        case "colour":
            if insideVideo { videoBuilder?.colour = (text == "yes" || text == "1") }

        case "aspect":
            if insideVideo { videoBuilder?.aspect = text }

        case "quality":
            if insideVideo { videoBuilder?.quality = text }

        case "present":
            if insideVideo { videoBuilder?.present = (text == "yes" || text == "1") }
            else if insideAudio { audioBuilder?.present = (text == "yes" || text == "1") }

        // MARK: Audio
        case "audio":
            insideAudio = false
            currentProgramme?.audio = audioBuilder?.build()
            audioBuilder = nil

        case "stereo":
            if insideAudio { audioBuilder?.stereo = text }

        // MARK: Subtitles
        case "subtitles":
            insideSubtitles = false
            if let builder = subtitleBuilder {
                currentProgramme?.subtitles.append(builder.build())
            }
            subtitleBuilder = nil

        // MARK: Review
        case "review":
            insideReview = false
            if let builder = reviewBuilder {
                if let review = builder.build(content: text) {
                    currentProgramme?.reviews.append(review)
                }
            }
            reviewBuilder = nil

        default:
            break
        }

        currentElement = ""
        currentText = ""
    }

    // MARK: - Helpers

    private func parseSourceInfo(from attributes: [String: String]) -> SourceInfo {
        SourceInfo(
            date: attributes["date"],
            sourceInfoURL: attributes["source-info-url"].flatMap { URL(string: $0) },
            sourceInfoName: attributes["source-info-name"],
            sourceDataURL: attributes["source-data-url"].flatMap { URL(string: $0) },
            generatorInfoName: attributes["generator-info-name"],
            generatorInfoURL: attributes["generator-info-url"].flatMap { URL(string: $0) }
        )
    }

    private func parseIcon(from attributes: [String: String]) -> Icon? {
        guard let src = attributes["src"], let url = URL(string: src) else { return nil }
        return Icon(
            src: url,
            width: attributes["width"].flatMap(Int.init),
            height: attributes["height"].flatMap(Int.init)
        )
    }

    private func parseImage(from attributes: [String: String], text: String) -> EPGImage? {
        guard let url = URL(string: text) else { return nil }
        return EPGImage(
            src: url,
            type: attributes["type"].flatMap { EPGImage.ImageType(rawValue: $0) },
            size: attributes["size"].flatMap { EPGImage.ImageSize(rawValue: $0) },
            orient: attributes["orient"].flatMap { EPGImage.Orientation(rawValue: $0) },
            system: attributes["system"]
        )
    }

    /// Parses an XMLTV date string into a `Date`.
    ///
    /// Supported formats:
    /// - `YYYYMMDDHHmmss +HHMM` (with timezone offset)
    /// - `YYYYMMDDHHmmss` (no timezone, treated as UTC)
    private func parseXMLTVDate(_ string: String) -> Date? {
        let s = string.trimmingCharacters(in: .whitespaces)

        // Try with timezone: YYYYMMDDHHmmss +HHMM
        if s.count >= 19 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMddHHmmss Z"
            if let date = formatter.date(from: String(s.prefix(20))) {
                return date
            }
        }

        // Try without timezone: YYYYMMDDHHmmss, treated as UTC
        if s.count >= 14 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMddHHmmss"
            if let date = formatter.date(from: String(s.prefix(14))) {
                return date
            }
        }

        // Try short format: YYYYMMDDHHmm
        if s.count >= 12 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMddHHmm"
            if let date = formatter.date(from: String(s.prefix(12))) {
                return date
            }
        }

        return nil
    }
}

// MARK: - Internal Builders

private final class ProgrammeBuilder: @unchecked Sendable {
    let channelID: String
    let start: Date
    let stop: Date?

    var pdcStart: Date?
    var vpsStart: Date?
    var showview: String?
    var videoplus: String?
    var clumpIndex: String?

    var titles: [LocalizedString] = []
    var subTitles: [LocalizedString] = []
    var descriptions: [LocalizedString] = []
    var categories: [LocalizedString] = []
    var keywords: [LocalizedString] = []
    var language: LocalizedString?
    var originalLanguage: LocalizedString?
    var countries: [LocalizedString] = []
    var date: String?
    var episodeNumbers: [EpisodeNumber] = []
    var icons: [Icon] = []
    var urls: [EPGUrl] = []
    var images: [EPGImage] = []
    var credits: Credits?
    var video: Video?
    var audio: Audio?
    var ratings: [Rating] = []
    var starRatings: [StarRating] = []
    var reviews: [Review] = []
    var subtitles: [Subtitle] = []
    var length: Length?
    var previouslyShown: PreviouslyShown?
    var isNew: Bool = false
    var isLive: Bool = false
    var lastChance: LocalizedString?
    var premiere: LocalizedString?

    init(channelID: String, start: Date, stop: Date?) {
        self.channelID = channelID
        self.start = start
        self.stop = stop
    }

    func build() -> Programme {
        Programme(
            channelID: channelID,
            start: start,
            stop: stop,
            titles: titles,
            pdcStart: pdcStart,
            vpsStart: vpsStart,
            showview: showview,
            videoplus: videoplus,
            clumpIndex: clumpIndex,
            subTitles: subTitles,
            descriptions: descriptions,
            categories: categories,
            keywords: keywords,
            language: language,
            originalLanguage: originalLanguage,
            countries: countries,
            date: date,
            episodeNumbers: episodeNumbers,
            icons: icons,
            urls: urls,
            images: images,
            credits: credits,
            video: video,
            audio: audio,
            ratings: ratings,
            starRatings: starRatings,
            reviews: reviews,
            subtitles: subtitles,
            length: length,
            previouslyShown: previouslyShown,
            isNew: isNew,
            isLive: isLive,
            lastChance: lastChance,
            premiere: premiere
        )
    }
}

private final class CreditsBuilder: @unchecked Sendable {
    var directors: [String] = []
    var actors: [Actor] = []
    var writers: [String] = []
    var adapters: [String] = []
    var producers: [String] = []
    var composers: [String] = []
    var editors: [String] = []
    var presenters: [String] = []
    var commentators: [String] = []
    var guests: [String] = []

    func build() -> Credits {
        Credits(
            directors: directors,
            actors: actors,
            writers: writers,
            adapters: adapters,
            producers: producers,
            composers: composers,
            editors: editors,
            presenters: presenters,
            commentators: commentators,
            guests: guests
        )
    }
}

private final class RatingBuilder: @unchecked Sendable {
    let system: String?
    var value: String = ""
    var icon: Icon?

    init(system: String?) { self.system = system }

    func build() -> Rating {
        Rating(value: value, system: system, icon: icon)
    }
}

private final class StarRatingBuilder: @unchecked Sendable {
    let system: String?
    var value: String = ""
    var icon: Icon?

    init(system: String?) { self.system = system }

    func build() -> StarRating {
        StarRating(value: value, system: system, icon: icon)
    }
}

private final class VideoBuilder: @unchecked Sendable {
    var colour: Bool?
    var aspect: String?
    var quality: String?
    var present: Bool?

    func build() -> Video {
        Video(colour: colour, aspect: aspect, quality: quality, present: present)
    }
}

private final class AudioBuilder: @unchecked Sendable {
    var present: Bool?
    var stereo: String?

    func build() -> Audio {
        Audio(present: present, stereo: stereo)
    }
}

private final class SubtitleBuilder: @unchecked Sendable {
    let type: String?
    var language: LocalizedString?

    init(type: String?) { self.type = type }

    func build() -> Subtitle {
        Subtitle(type: type, language: language)
    }
}

private final class ActorBuilder: @unchecked Sendable {
    let role: String?
    let guest: Bool
    var image: EPGImage?
    var url: EPGUrl?
    /// Accumulates the direct text content of the `<actor>` element (the actor's name).
    /// Populated separately from `currentText` because child elements (`<image>`, `<url>`)
    /// reset `currentText` before `didEndElement("actor")` fires.
    var nameBuffer: String = ""

    init(role: String?, guest: Bool) {
        self.role = role
        self.guest = guest
    }

    func build() -> Actor {
        let name = nameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        return Actor(name: name, role: role, guest: guest, image: image, url: url)
    }
}

private final class ReviewBuilder: @unchecked Sendable {
    let typeString: String?
    let source: String?
    let reviewer: String?
    let language: String?

    init(type: String?, source: String?, reviewer: String?, language: String?) {
        self.typeString = type
        self.source = source
        self.reviewer = reviewer
        self.language = language
    }

    func build(content: String) -> Review? {
        guard !content.isEmpty else { return nil }
        let reviewType = typeString.flatMap { Review.ReviewType(rawValue: $0) } ?? .text
        return Review(
            type: reviewType,
            content: content,
            source: source,
            reviewer: reviewer,
            language: language
        )
    }
}
