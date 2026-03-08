import Foundation

/// A type that can parse raw EPG data into an ``EPGData`` value.
///
/// Implement this protocol to add support for a custom EPG format.
///
/// ## Example
/// ```swift
/// public struct MyCustomParser: EPGParser {
///     public func parse(data: Data) throws -> EPGData {
///         // custom parsing logic
///         return EPGData(channels: [], programmes: [])
///     }
/// }
/// ```
public protocol EPGParser: Sendable {

    /// Parses raw EPG data and returns the structured result.
    ///
    /// - Parameter data: The raw EPG bytes.
    /// - Returns: The parsed ``EPGData``.
    /// - Throws: An ``EPGError`` on failure.
    func parse(data: Data) throws -> EPGData
}

// MARK: - EPGFormat

/// The format of an EPG data source.
///
/// Pass a format value to ``EPGKit`` to select the appropriate parser.
public enum EPGFormat: Sendable, Equatable {

    /// The XMLTV open standard format.
    ///
    /// This is the most widely used EPG format. See http://wiki.xmltv.org/index.php/XMLTVFormat
    case xmltv

    /// A custom parser supplied by the caller.
    case custom(any EPGParser)

    public static func == (lhs: EPGFormat, rhs: EPGFormat) -> Bool {
        switch (lhs, rhs) {
        case (.xmltv, .xmltv): return true
        default: return false
        }
    }
}
