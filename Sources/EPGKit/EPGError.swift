import Foundation

/// Errors that can occur when parsing EPG data.
public enum EPGError: Error, Sendable, Equatable {

    // MARK: - Parse Errors

    /// The input data is empty.
    case emptyData

    /// XML parsing failed.
    /// - Parameter reason: A description of why parsing failed.
    case xmlParsingFailed(reason: String)

    /// The XML document has an unexpected structure.
    /// - Parameter element: The name of the problematic element.
    case invalidXMLStructure(element: String)

    /// A required field is missing.
    /// - Parameter field: The name of the missing field.
    case missingRequiredField(field: String)

    /// A date string could not be parsed.
    /// - Parameter value: The date string that failed to parse.
    case invalidDateFormat(value: String)

    /// A URL string is malformed.
    /// - Parameter value: The invalid URL string.
    case invalidURL(value: String)

    // MARK: - Data Errors

    /// The EPG format is not supported.
    case unsupportedFormat

    /// The data cannot be decoded with the specified encoding.
    case invalidEncoding

    // MARK: - Network Errors

    /// A network request failed.
    /// - Parameter underlying: The underlying error from URLSession.
    case networkError(underlying: any Error)

    // MARK: - Equatable

    public static func == (lhs: EPGError, rhs: EPGError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyData, .emptyData): return true
        case (.xmlParsingFailed(let l), .xmlParsingFailed(let r)): return l == r
        case (.invalidXMLStructure(let l), .invalidXMLStructure(let r)): return l == r
        case (.missingRequiredField(let l), .missingRequiredField(let r)): return l == r
        case (.invalidDateFormat(let l), .invalidDateFormat(let r)): return l == r
        case (.invalidURL(let l), .invalidURL(let r)): return l == r
        case (.unsupportedFormat, .unsupportedFormat): return true
        case (.invalidEncoding, .invalidEncoding): return true
        case (.networkError, .networkError): return false
        default: return false
        }
    }
}

extension EPGError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyData:
            return "EPG data is empty."
        case .xmlParsingFailed(let reason):
            return "XML parsing failed: \(reason)"
        case .invalidXMLStructure(let element):
            return "Invalid XML structure at element: \(element)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidDateFormat(let value):
            return "Invalid date format: \(value)"
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .unsupportedFormat:
            return "Unsupported EPG format."
        case .invalidEncoding:
            return "Invalid data encoding. Ensure the data is UTF-8 encoded."
        case .networkError(let underlying):
            return "Network request failed: \(underlying.localizedDescription)"
        }
    }
}
