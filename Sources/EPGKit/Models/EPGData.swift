import Foundation

/// The result of parsing an EPG data source.
///
/// Contains all channels and programmes parsed from an EPG feed and exposes
/// convenient query methods for common scheduling lookups.
///
/// ## Usage
/// ```swift
/// let kit = EPGKit()
/// let data = try await kit.parse(url: epgURL)
///
/// // All channels
/// let channels = data.channels
///
/// // Programmes for a specific channel
/// let programmes = data.programmes(for: "bbc1.bbc.co.uk")
///
/// // What's on right now
/// let current = data.currentProgrammes(at: Date())
/// ```
public struct EPGData: Sendable, Equatable {

    /// All channels, in the order they appear in the source.
    public let channels: [Channel]

    /// All programmes, sorted by start time.
    public let programmes: [Programme]

    /// Metadata about the EPG data source.
    public let sourceInfo: SourceInfo?

    // Fast lookup tables built at init time.
    private let channelIndex: [String: Channel]
    private let programmeIndex: [String: [Programme]]

    public init(channels: [Channel], programmes: [Programme], sourceInfo: SourceInfo? = nil) {
        self.channels = channels
        self.sourceInfo = sourceInfo

        let sortedProgrammes = programmes.sorted { $0.start < $1.start }
        self.programmes = sortedProgrammes

        self.channelIndex = Dictionary(
            channels.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.programmeIndex = Dictionary(
            grouping: sortedProgrammes,
            by: \.channelID
        )
    }

    // MARK: - Channel Queries

    /// Returns the channel with the given ID, or `nil` if not found.
    ///
    /// - Parameter id: The channel's unique identifier.
    public func channel(for id: String) -> Channel? {
        channelIndex[id]
    }

    // MARK: - Programme Queries

    /// Returns all programmes for the specified channel, sorted by start time.
    ///
    /// - Parameter channelID: The channel identifier.
    public func programmes(for channelID: String) -> [Programme] {
        programmeIndex[channelID] ?? []
    }

    /// Returns all programmes whose start time falls within the given range.
    ///
    /// - Parameter range: The date range to filter by.
    public func programmes(in range: ClosedRange<Date>) -> [Programme] {
        programmes.filter { range.contains($0.start) }
    }

    /// Returns programmes for a specific channel whose start time falls within the given range.
    ///
    /// - Parameters:
    ///   - channelID: The channel identifier.
    ///   - range: The date range to filter by.
    public func programmes(for channelID: String, in range: ClosedRange<Date>) -> [Programme] {
        programmes(for: channelID).filter { range.contains($0.start) }
    }

    /// Returns the programme currently airing on the given channel at the specified time.
    ///
    /// - Parameters:
    ///   - channelID: The channel identifier.
    ///   - date: The point in time to check. Defaults to now.
    /// - Returns: The airing programme, or `nil` if none is found.
    public func currentProgramme(for channelID: String, at date: Date = Date()) -> Programme? {
        programmes(for: channelID).last(where: { programme in
            if let stop = programme.stop {
                return programme.start <= date && date < stop
            } else {
                return programme.start <= date
            }
        })
    }

    /// Returns the currently airing programme for every channel at the specified time.
    ///
    /// - Parameter date: The point in time to check. Defaults to now.
    /// - Returns: A dictionary mapping channel IDs to their current programme.
    public func currentProgrammes(at date: Date = Date()) -> [String: Programme] {
        var result: [String: Programme] = [:]
        for channel in channels {
            if let programme = currentProgramme(for: channel.id, at: date) {
                result[channel.id] = programme
            }
        }
        return result
    }

    /// Returns the next programme scheduled after the given time on the specified channel.
    ///
    /// - Parameters:
    ///   - channelID: The channel identifier.
    ///   - date: The reference point in time. Defaults to now.
    /// - Returns: The next programme, or `nil` if none is found.
    public func nextProgramme(for channelID: String, after date: Date = Date()) -> Programme? {
        programmes(for: channelID).first(where: { $0.start > date })
    }

    // MARK: - Statistics

    /// The total number of channels.
    public var channelCount: Int { channels.count }

    /// The total number of programmes.
    public var programmeCount: Int { programmes.count }

    /// The earliest start time across all programmes.
    public var earliestDate: Date? { programmes.first?.start }

    /// The latest stop time across all programmes.
    public var latestDate: Date? { programmes.compactMap(\.stop).max() }
}
