import Foundation

/// The main entry point for EPGKit.
///
/// Provides a unified API for parsing EPG data from `Data`, `String`, or a remote `URL`.
///
/// ## Quick Start
///
/// ### Parse from a URL
/// ```swift
/// let kit = EPGKit()
/// do {
///     let epg = try await kit.parse(url: URL(string: "https://example.com/epg.xml")!)
///     print("\(epg.channelCount) channels, \(epg.programmeCount) programmes")
/// } catch {
///     print("Parsing failed: \(error)")
/// }
/// ```
///
/// ### Parse from local data
/// ```swift
/// let kit = EPGKit()
/// let data = try Data(contentsOf: localFileURL)
/// let epg = try kit.parse(data: data)
/// ```
///
/// ### Query the schedule
/// ```swift
/// // What's on right now
/// let current = epg.currentProgrammes(at: Date())
///
/// // Today's schedule for a specific channel
/// let startOfDay = Calendar.current.startOfDay(for: Date())
/// let endOfDay = startOfDay.addingTimeInterval(86400)
/// let today = epg.programmes(for: "bbc1", in: startOfDay...endOfDay)
/// ```
///
/// ## Supported Formats
///
/// - ``EPGFormat/xmltv``: XMLTV XML format (default)
/// - ``EPGFormat/custom(_:)``: A caller-supplied ``EPGParser`` implementation
///
/// ## Swift 6 Concurrency
///
/// `EPGKit` is a `Sendable` value type. All methods are safe to call from
/// concurrent contexts. Network requests use the `URLSession` async/await API.
public struct EPGKit: Sendable {

    private let urlSession: URLSession

    /// Creates an EPGKit instance.
    ///
    /// - Parameter urlSession: The session used for network requests. Defaults to `.shared`.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Parse from Data

    /// Parses EPG data from a `Data` value.
    ///
    /// - Parameters:
    ///   - data: The raw EPG bytes.
    ///   - format: The EPG format. Defaults to ``EPGFormat/xmltv``.
    /// - Returns: The parsed ``EPGData``.
    /// - Throws: ``EPGError``
    public func parse(data: Data, format: EPGFormat = .xmltv) throws -> EPGData {
        let parser = makeParser(for: format)
        return try parser.parse(data: data)
    }

    // MARK: - Parse from String

    /// Parses EPG data from a `String`.
    ///
    /// - Parameters:
    ///   - string: The EPG XML string.
    ///   - encoding: The string encoding. Defaults to `.utf8`.
    ///   - format: The EPG format. Defaults to ``EPGFormat/xmltv``.
    /// - Returns: The parsed ``EPGData``.
    /// - Throws: ``EPGError``
    public func parse(
        string: String,
        encoding: String.Encoding = .utf8,
        format: EPGFormat = .xmltv
    ) throws -> EPGData {
        guard let data = string.data(using: encoding) else {
            throw EPGError.invalidEncoding
        }
        return try parse(data: data, format: format)
    }

    // MARK: - Parse from URL (async)

    /// Downloads and parses EPG data from a URL.
    ///
    /// Supports both remote (`https://`) and local (`file://`) URLs.
    ///
    /// - Parameters:
    ///   - url: The remote or local file URL of the EPG feed.
    ///   - format: The EPG format. Defaults to ``EPGFormat/xmltv``.
    /// - Returns: The parsed ``EPGData``.
    /// - Throws: ``EPGError`` (network or parse error)
    public func parse(url: URL, format: EPGFormat = .xmltv) async throws -> EPGData {
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            return try parse(data: data, format: format)
        }

        let data: Data
        do {
            let (responseData, _) = try await urlSession.data(from: url)
            data = responseData
        } catch let error as EPGError {
            throw error
        } catch {
            throw EPGError.networkError(underlying: error)
        }

        return try parse(data: data, format: format)
    }

    // MARK: - Private

    private func makeParser(for format: EPGFormat) -> any EPGParser {
        switch format {
        case .xmltv:
            return XMLTVParser()
        case .custom(let parser):
            return parser
        }
    }
}
