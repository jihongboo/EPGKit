import Foundation

/// An EPG programme (a scheduled broadcast).
///
/// Corresponds to the `<programme>` element in the XMLTV specification.
///
/// ## Example XMLTV
/// ```xml
/// <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="bbc1.bbc.co.uk">
///   <title lang="en">The News at One</title>
///   <desc lang="en">The lunchtime news bulletin.</desc>
///   <category lang="en">News</category>
///   <icon src="https://example.com/news.png"/>
///   <episode-num system="xmltv_ns">0.0.0/1</episode-num>
///   <rating system="MPAA">
///     <value>PG</value>
///   </rating>
/// </programme>
/// ```
public struct Programme: Sendable, Equatable, Hashable {

    // MARK: - Required Fields

    /// The ID of the channel this programme airs on (the XMLTV `channel` attribute).
    public let channelID: String

    /// The broadcast start time (the XMLTV `start` attribute).
    public let start: Date

    /// The broadcast end time (the XMLTV `stop` attribute).
    public let stop: Date?

    /// All titles for the programme, potentially in multiple languages.
    /// At least one is required by the XMLTV specification.
    public let titles: [LocalizedString]

    // MARK: - Optional Programme Attributes

    /// PDC (Programme Delivery Control) start time.
    public let pdcStart: Date?

    /// VPS start time.
    public let vpsStart: Date?

    /// Gemstar Showview code.
    public let showview: String?

    /// VideoPlus code.
    public let videoplus: String?

    /// Index for programmes that share the same timeslot (e.g. `"0/2"`, `"1/2"`).
    public let clumpIndex: String?

    // MARK: - Optional Child Elements

    /// Sub-titles (episode titles).
    public let subTitles: [LocalizedString]

    /// Programme descriptions.
    public let descriptions: [LocalizedString]

    /// Content categories (e.g. "News", "Film").
    public let categories: [LocalizedString]

    /// Keywords associated with the programme.
    public let keywords: [LocalizedString]

    /// The broadcast language.
    public let language: LocalizedString?

    /// The original broadcast language (before dubbing).
    public let originalLanguage: LocalizedString?

    /// The country or countries of production. Multiple values are allowed by the XMLTV spec.
    public let countries: [LocalizedString]

    /// The production year or date string.
    public let date: String?

    /// Episode number entries (may use multiple numbering systems).
    public let episodeNumbers: [EpisodeNumber]

    /// Programme icons/thumbnails. The XMLTV `<icon>` element; may appear multiple times.
    public let icons: [Icon]

    /// Website URLs associated with this programme.
    public let urls: [EPGUrl]

    /// Programme images (posters, backdrops, stills). Corresponds to `<image>` elements.
    public let images: [EPGImage]

    /// Cast and crew credits.
    public let credits: Credits?

    /// Video format details.
    public let video: Video?

    /// Audio format details.
    public let audio: Audio?

    /// Content ratings.
    public let ratings: [Rating]

    /// Star / quality ratings.
    public let starRatings: [StarRating]

    /// Programme reviews.
    public let reviews: [Review]

    /// Available subtitle tracks.
    public let subtitles: [Subtitle]

    /// The stated programme length.
    public let length: Length?

    /// Prior broadcast information. Present when the programme is a repeat.
    public let previouslyShown: PreviouslyShown?

    /// Whether this is a first-run broadcast.
    public let isNew: Bool

    /// Whether this is a live broadcast.
    public let isLive: Bool

    /// Last-chance information. Present when this is the final scheduled showing.
    ///
    /// Corresponds to the `<last-chance>` element. When present with no text content,
    /// the value is an empty `LocalizedString`.
    public let lastChance: LocalizedString?

    /// Premiere information and optional text.
    public let premiere: LocalizedString?

    public init(
        channelID: String,
        start: Date,
        stop: Date? = nil,
        titles: [LocalizedString],
        pdcStart: Date? = nil,
        vpsStart: Date? = nil,
        showview: String? = nil,
        videoplus: String? = nil,
        clumpIndex: String? = nil,
        subTitles: [LocalizedString] = [],
        descriptions: [LocalizedString] = [],
        categories: [LocalizedString] = [],
        keywords: [LocalizedString] = [],
        language: LocalizedString? = nil,
        originalLanguage: LocalizedString? = nil,
        countries: [LocalizedString] = [],
        date: String? = nil,
        episodeNumbers: [EpisodeNumber] = [],
        icons: [Icon] = [],
        urls: [EPGUrl] = [],
        images: [EPGImage] = [],
        credits: Credits? = nil,
        video: Video? = nil,
        audio: Audio? = nil,
        ratings: [Rating] = [],
        starRatings: [StarRating] = [],
        reviews: [Review] = [],
        subtitles: [Subtitle] = [],
        length: Length? = nil,
        previouslyShown: PreviouslyShown? = nil,
        isNew: Bool = false,
        isLive: Bool = false,
        lastChance: LocalizedString? = nil,
        premiere: LocalizedString? = nil
    ) {
        self.channelID = channelID
        self.start = start
        self.stop = stop
        self.titles = titles
        self.pdcStart = pdcStart
        self.vpsStart = vpsStart
        self.showview = showview
        self.videoplus = videoplus
        self.clumpIndex = clumpIndex
        self.subTitles = subTitles
        self.descriptions = descriptions
        self.categories = categories
        self.keywords = keywords
        self.language = language
        self.originalLanguage = originalLanguage
        self.countries = countries
        self.date = date
        self.episodeNumbers = episodeNumbers
        self.icons = icons
        self.urls = urls
        self.images = images
        self.credits = credits
        self.video = video
        self.audio = audio
        self.ratings = ratings
        self.starRatings = starRatings
        self.reviews = reviews
        self.subtitles = subtitles
        self.length = length
        self.previouslyShown = previouslyShown
        self.isNew = isNew
        self.isLive = isLive
        self.lastChance = lastChance
        self.premiere = premiere
    }

    // MARK: - Convenience

    /// The primary title (the first entry in ``titles``).
    public var title: String? { titles.first?.value }

    /// The primary description (the first entry in ``descriptions``).
    public var description: String? { descriptions.first?.value }

    /// The primary category (the first entry in ``categories``).
    public var category: String? { categories.first?.value }

    /// The primary icon (the first entry in ``icons``).
    public var icon: Icon? { icons.first }

    /// The primary country of production.
    public var country: LocalizedString? { countries.first }

    /// The duration of the programme in seconds, or `nil` when ``stop`` is not set.
    public var duration: TimeInterval? {
        guard let stop else { return nil }
        return stop.timeIntervalSince(start)
    }

    /// Returns the episode number entry for the specified numbering system.
    ///
    /// - Parameter system: The numbering system identifier (e.g. `xmltv_ns`, `onscreen`).
    public func episodeNumber(for system: String) -> EpisodeNumber? {
        episodeNumbers.first(where: { $0.system == system })
    }

    /// Returns the title for the specified language, falling back to the primary title.
    public func title(for language: String) -> String? {
        titles.first(where: { $0.language == language })?.value ?? titles.first?.value
    }

    /// Returns the description for the specified language, falling back to the primary description.
    public func description(for language: String) -> String? {
        descriptions.first(where: { $0.language == language })?.value ?? descriptions.first?.value
    }
}

extension Programme: Identifiable {
    /// A stable identifier derived from the channel ID and start timestamp.
    public var id: String {
        "\(channelID)-\(Int(start.timeIntervalSince1970))"
    }
}
