import Foundation

// MARK: - LocalizedString

/// A string value paired with an optional language tag.
///
/// Used to represent text content that may have multiple language variants,
/// following the language attribute convention in the XMLTV specification.
public struct LocalizedString: Sendable, Equatable, Hashable {

    /// The text content.
    public let value: String

    /// The language code (e.g. `en`, `de`), conforming to BCP 47.
    public let language: String?

    public init(value: String, language: String? = nil) {
        self.value = value
        self.language = language
    }
}

extension LocalizedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value
        self.language = nil
    }
}

extension LocalizedString: CustomStringConvertible {
    public var description: String { value }
}

// MARK: - EPGUrl

/// A URL with an optional source system identifier.
///
/// Corresponds to the `<url>` element in the XMLTV specification.
/// The `system` attribute identifies the source database (e.g. `"IMDb"`, `"TMDB"`).
public struct EPGUrl: Sendable, Equatable, Hashable {

    /// The URL.
    public let url: URL

    /// The optional source system identifier (e.g. `"IMDb"`, `"TMDB"`).
    public let system: String?

    public init(url: URL, system: String? = nil) {
        self.url = url
        self.system = system
    }
}

// MARK: - Icon

/// An image or icon resource.
///
/// Corresponds to the `<icon>` element in the XMLTV specification.
public struct Icon: Sendable, Equatable, Hashable {

    /// The URL of the icon resource.
    public let src: URL

    /// The width of the icon in pixels.
    public let width: Int?

    /// The height of the icon in pixels.
    public let height: Int?

    public init(src: URL, width: Int? = nil, height: Int? = nil) {
        self.src = src
        self.width = width
        self.height = height
    }
}

// MARK: - EpisodeNumber

/// An episode number in a specific numbering system.
///
/// Corresponds to the `<episode-num>` element in the XMLTV specification.
/// Multiple numbering systems may be present on the same programme.
public struct EpisodeNumber: Sendable, Equatable, Hashable {

    /// The identifier of the numbering system.
    ///
    /// Common values:
    /// - `xmltv_ns`: XMLTV namespace format (e.g. `1.2.0/1` = season 2, episode 3)
    /// - `dd_progid`: Digital delivery programme ID
    /// - `onscreen`: On-screen display format (e.g. `S01E02`)
    public let system: String?

    /// The raw episode number value.
    public let value: String

    public init(value: String, system: String? = nil) {
        self.value = value
        self.system = system
    }

    /// Parses the `xmltv_ns` season/episode/part components.
    ///
    /// The format is `season.episode.part/total`, all zero-based.
    /// For example `1.2.0/1` means season 2, episode 3, part 1 of 1.
    public var xmltvComponents: (season: Int?, episode: Int?, part: Int?)? {
        guard system == "xmltv_ns" else { return nil }
        let parts = value.split(separator: ".", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        func parse(_ s: String) -> Int? {
            // Handle "n/total" format — take the numerator
            let num = s.split(separator: "/").first.map(String.init) ?? s
            return Int(num.trimmingCharacters(in: .whitespaces)).map { $0 + 1 }
        }

        return (
            season: parse(parts[0]),
            episode: parse(parts[1]),
            part: parts.count > 2 ? parse(parts[2]) : nil
        )
    }
}

// MARK: - Rating

/// A content rating from a specific rating system.
///
/// Corresponds to the `<rating>` element in the XMLTV specification.
public struct Rating: Sendable, Equatable, Hashable {

    /// The rating system (e.g. `MPAA`, `VCHIP`, `FSK`).
    public let system: String?

    /// The rating value (e.g. `PG`, `PG-13`, `R`).
    public let value: String

    /// An optional icon representing the rating.
    public let icon: Icon?

    public init(value: String, system: String? = nil, icon: Icon? = nil) {
        self.value = value
        self.system = system
        self.icon = icon
    }
}

// MARK: - StarRating

/// A star-based quality rating.
///
/// Corresponds to the `<star-rating>` element in the XMLTV specification.
public struct StarRating: Sendable, Equatable, Hashable {

    /// The rating system identifier.
    public let system: String?

    /// The rating value, typically in `n/m` format (e.g. `7/10`).
    public let value: String

    /// An optional icon representing the star rating.
    public let icon: Icon?

    public init(value: String, system: String? = nil, icon: Icon? = nil) {
        self.value = value
        self.system = system
        self.icon = icon
    }

    /// Returns the rating as a normalised score between 0 and 1.
    ///
    /// For example `7/10` returns `0.7`. Returns `nil` if the value cannot be parsed.
    public var normalizedScore: Double? {
        let parts = value.split(separator: "/").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, parts[1] > 0 else { return nil }
        return parts[0] / parts[1]
    }
}

// MARK: - Credits

/// The cast and crew of a programme.
///
/// Corresponds to the `<credits>` element in the XMLTV specification.
public struct Credits: Sendable, Equatable, Hashable {

    /// Directors.
    public let directors: [String]

    /// Actors, optionally with their roles.
    public let actors: [Actor]

    /// Writers.
    public let writers: [String]

    /// Adapters.
    public let adapters: [String]

    /// Producers.
    public let producers: [String]

    /// Composers.
    public let composers: [String]

    /// Editors.
    public let editors: [String]

    /// Presenters / hosts.
    public let presenters: [String]

    /// Commentators.
    public let commentators: [String]

    /// Guests.
    public let guests: [String]

    public init(
        directors: [String] = [],
        actors: [Actor] = [],
        writers: [String] = [],
        adapters: [String] = [],
        producers: [String] = [],
        composers: [String] = [],
        editors: [String] = [],
        presenters: [String] = [],
        commentators: [String] = [],
        guests: [String] = []
    ) {
        self.directors = directors
        self.actors = actors
        self.writers = writers
        self.adapters = adapters
        self.producers = producers
        self.composers = composers
        self.editors = editors
        self.presenters = presenters
        self.commentators = commentators
        self.guests = guests
    }

    /// All names across all roles.
    public var allNames: [String] {
        directors + actors.map(\.name) + writers + adapters +
        producers + composers + editors + presenters + commentators + guests
    }

    /// Returns `true` when no credits are present.
    public var isEmpty: Bool { allNames.isEmpty }
}

// MARK: - Actor

/// An actor and the optional role they play.
public struct Actor: Sendable, Equatable, Hashable {

    /// The actor's name.
    public let name: String

    /// The character or role they play.
    public let role: String?

    /// Whether the actor is a guest appearance (`guest="yes"` in XMLTV).
    public let guest: Bool

    /// An image associated with the actor (e.g. headshot). Corresponds to the `<image>` child element.
    public let image: EPGImage?

    /// A URL associated with the actor (e.g. profile page). Corresponds to the `<url>` child element.
    public let url: EPGUrl?

    public init(name: String, role: String? = nil, guest: Bool = false, image: EPGImage? = nil, url: EPGUrl? = nil) {
        self.name = name
        self.role = role
        self.guest = guest
        self.image = image
        self.url = url
    }
}

// MARK: - Video

/// Video quality and format information.
///
/// Corresponds to the `<video>` element in the XMLTV specification.
public struct Video: Sendable, Equatable, Hashable {

    /// Whether the programme is in colour (`true`) or black-and-white (`false`).
    public let colour: Bool?

    /// The aspect ratio (e.g. `16:9`, `4:3`).
    public let aspect: String?

    /// The video quality (e.g. `HDTV`, `576i`, `720p`, `1080i`).
    public let quality: String?

    /// Whether video is present.
    public let present: Bool?

    public init(colour: Bool? = nil, aspect: String? = nil, quality: String? = nil, present: Bool? = nil) {
        self.colour = colour
        self.aspect = aspect
        self.quality = quality
        self.present = present
    }
}

// MARK: - Audio

/// Audio format information.
///
/// Corresponds to the `<audio>` element in the XMLTV specification.
public struct Audio: Sendable, Equatable, Hashable {

    /// Whether audio is present.
    public let present: Bool?

    /// The stereo type (e.g. `mono`, `stereo`, `surround`, `dolby`).
    public let stereo: String?

    public init(present: Bool? = nil, stereo: String? = nil) {
        self.present = present
        self.stereo = stereo
    }
}

// MARK: - Subtitle

/// Subtitle track information.
///
/// Corresponds to the `<subtitles>` element in the XMLTV specification.
public struct Subtitle: Sendable, Equatable, Hashable {

    /// The subtitle type (e.g. `teletext`, `onscreen`, `deaf-signed`).
    public let type: String?

    /// The language of the subtitle track.
    public let language: LocalizedString?

    public init(type: String? = nil, language: LocalizedString? = nil) {
        self.type = type
        self.language = language
    }
}

// MARK: - PreviouslyShown

/// Information about a prior broadcast of the same programme.
///
/// Corresponds to the `<previously-shown>` element in the XMLTV specification.
public struct PreviouslyShown: Sendable, Equatable, Hashable {

    /// When the programme was first broadcast.
    public let start: Date?

    /// The channel on which it was first broadcast.
    public let channel: String?

    public init(start: Date? = nil, channel: String? = nil) {
        self.start = start
        self.channel = channel
    }
}

// MARK: - Length

/// The stated length of a programme.
///
/// Corresponds to the `<length>` element in the XMLTV specification.
public struct Length: Sendable, Equatable, Hashable {

    /// The unit of the length value (`seconds`, `minutes`, or `hours`).
    public let units: String

    /// The numeric length in the specified units.
    public let value: Int

    public init(value: Int, units: String) {
        self.value = value
        self.units = units
    }

    /// The length converted to seconds.
    public var seconds: TimeInterval {
        switch units {
        case "hours": return TimeInterval(value) * 3600
        case "minutes": return TimeInterval(value) * 60
        default: return TimeInterval(value)
        }
    }
}

// MARK: - SourceInfo

/// Metadata about the EPG data source.
///
/// Corresponds to attributes on the root `<tv>` element in the XMLTV specification.
public struct SourceInfo: Sendable, Equatable, Hashable {

    /// The date the listings were originally produced (the `date` attribute).
    public let date: String?

    /// The URL of the source website.
    public let sourceInfoURL: URL?

    /// The human-readable name of the data source.
    public let sourceInfoName: String?

    /// The URL where the raw data was fetched from.
    public let sourceDataURL: URL?

    /// The name of the tool that generated this EPG file.
    public let generatorInfoName: String?

    /// The URL of the generating tool.
    public let generatorInfoURL: URL?

    public init(
        date: String? = nil,
        sourceInfoURL: URL? = nil,
        sourceInfoName: String? = nil,
        sourceDataURL: URL? = nil,
        generatorInfoName: String? = nil,
        generatorInfoURL: URL? = nil
    ) {
        self.date = date
        self.sourceInfoURL = sourceInfoURL
        self.sourceInfoName = sourceInfoName
        self.sourceDataURL = sourceDataURL
        self.generatorInfoName = generatorInfoName
        self.generatorInfoURL = generatorInfoURL
    }
}

// MARK: - Review

/// A programme review.
///
/// Corresponds to the `<review>` element in the XMLTV specification.
public struct Review: Sendable, Equatable, Hashable {

    /// The type of review content.
    public enum ReviewType: String, Sendable, Equatable, Hashable {
        /// Plain-text review.
        case text
        /// A URL pointing to an external review.
        case url
    }

    /// Whether the content is plain text or a URL.
    public let type: ReviewType

    /// The review text or URL string.
    public let content: String

    /// The source publication or service (e.g. `"RT"`, `"IMDb"`).
    public let source: String?

    /// The reviewer's name.
    public let reviewer: String?

    /// The language of the review.
    public let language: String?

    public init(
        type: ReviewType,
        content: String,
        source: String? = nil,
        reviewer: String? = nil,
        language: String? = nil
    ) {
        self.type = type
        self.content = content
        self.source = source
        self.reviewer = reviewer
        self.language = language
    }
}

// MARK: - EPGImage

/// A programme or person image.
///
/// Corresponds to the `<image>` element in the XMLTV specification.
/// This is distinct from ``Icon``, which maps to the `<icon>` element.
public struct EPGImage: Sendable, Equatable, Hashable {

    /// The role or context of the image.
    public enum ImageType: String, Sendable, Equatable, Hashable {
        case poster, backdrop, still, person, character
    }

    /// The approximate size bucket of the image.
    public enum ImageSize: String, Sendable, Equatable, Hashable {
        /// Smaller than 200 px on the longest side.
        case small = "1"
        /// 200–400 px.
        case medium = "2"
        /// Larger than 400 px.
        case large = "3"
    }

    /// The orientation of the image.
    public enum Orientation: String, Sendable, Equatable, Hashable {
        case portrait = "P"
        case landscape = "L"
    }

    /// The URL of the image.
    public let src: URL

    /// The image type.
    public let type: ImageType?

    /// The size bucket.
    public let size: ImageSize?

    /// The orientation.
    public let orient: Orientation?

    /// The system that provided this image (e.g. `"tvdb"`, `"tmdb"`, `"imdb"`).
    public let system: String?

    public init(
        src: URL,
        type: ImageType? = nil,
        size: ImageSize? = nil,
        orient: Orientation? = nil,
        system: String? = nil
    ) {
        self.src = src
        self.type = type
        self.size = size
        self.orient = orient
        self.system = system
    }
}
