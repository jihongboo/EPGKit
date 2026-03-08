import Foundation

/// An EPG channel.
///
/// Corresponds to the `<channel>` element in the XMLTV specification.
///
/// ## Example XMLTV
/// ```xml
/// <channel id="bbc1.bbc.co.uk">
///   <display-name lang="en">BBC One</display-name>
///   <icon src="https://example.com/bbc1.png" width="100" height="100"/>
///   <url>https://www.bbc.co.uk/bbcone</url>
/// </channel>
/// ```
public struct Channel: Sendable, Identifiable, Equatable, Hashable {

    /// The unique channel identifier (the XMLTV `id` attribute).
    ///
    /// Should follow an RFC 2838 DNS-like form, e.g. `bbc1.bbc.co.uk`.
    public let id: String

    /// All display names for the channel, potentially in multiple languages.
    ///
    /// The first element is treated as the primary display name.
    /// At least one is required by the XMLTV specification.
    public let displayNames: [LocalizedString]

    /// Channel icons/logos. The XMLTV spec allows multiple icons per channel.
    public let icons: [Icon]

    /// Website URLs associated with this channel.
    public let urls: [EPGUrl]

    public init(
        id: String,
        displayNames: [LocalizedString],
        icons: [Icon] = [],
        urls: [EPGUrl] = []
    ) {
        self.id = id
        self.displayNames = displayNames
        self.icons = icons
        self.urls = urls
    }

    /// The primary display name (the first entry in ``displayNames``).
    public var displayName: String? {
        displayNames.first?.value
    }

    /// The primary icon (the first entry in ``icons``).
    public var icon: Icon? {
        icons.first
    }

    /// The primary URL (the first entry in ``urls``).
    public var url: EPGUrl? {
        urls.first
    }

    /// Returns the display name for the given language, falling back to the primary name.
    ///
    /// - Parameter language: A BCP 47 language code (e.g. `en`, `de`).
    /// - Returns: The matching display name, or the first display name if no match is found.
    public func displayName(for language: String) -> String? {
        displayNames.first(where: { $0.language == language })?.value ?? displayNames.first?.value
    }
}
