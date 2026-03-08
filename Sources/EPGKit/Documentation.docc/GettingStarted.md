# Getting Started

Learn how to integrate EPGKit into your project and parse EPG data.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/EPGKit.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["EPGKit"]
    ),
]
```

## Parsing EPG Data

### From a URL

The most common use case is fetching and parsing EPG from a remote server:

```swift
import EPGKit

let kit = EPGKit()

do {
    let epg = try await kit.parse(url: URL(string: "https://example.com/epg.xml")!)
    print("Parsed \(epg.channelCount) channels")
} catch EPGError.networkError(let underlying) {
    print("Network error: \(underlying)")
} catch EPGError.xmlParsingFailed(let reason) {
    print("XML parse failed: \(reason)")
} catch {
    print("Error: \(error)")
}
```

### From a Local File

```swift
let kit = EPGKit()
let fileURL = Bundle.main.url(forResource: "epg", withExtension: "xml")!
let epg = try await kit.parse(url: fileURL)
```

### From Data or String

```swift
// From Data
let data = try Data(contentsOf: fileURL)
let epg = try kit.parse(data: data)

// From String
let xmlString = "..."
let epg = try kit.parse(string: xmlString)
```

## Querying Channels

```swift
// All channels
for channel in epg.channels {
    print(channel.id, channel.displayName ?? "Unknown")
}

// Look up by ID
if let ch = epg.channel(for: "bbc1.bbc.co.uk") {
    print(ch.displayName(for: "en"))
}
```

## Querying Programmes

### Currently Airing

```swift
// Single channel
let current = epg.currentProgramme(for: "bbc1.bbc.co.uk")

// All channels
let allCurrent = epg.currentProgrammes(at: Date())
```

### Programmes in a Time Range

```swift
let start = Calendar.current.startOfDay(for: Date())
let end = start.addingTimeInterval(86400)
let todayProgrammes = epg.programmes(for: "bbc1.bbc.co.uk", in: start...end)
```

### Next Programme

```swift
let next = epg.nextProgramme(for: "bbc1.bbc.co.uk", after: Date())
print("Up next: \(next?.title ?? "none")")
```

## Custom Parsers

Implement ``EPGParser`` to support a custom format:

```swift
struct MyCustomParser: EPGParser {
    func parse(data: Data) throws -> EPGData {
        // custom parsing logic
        return EPGData(channels: [], programmes: [])
    }
}

let kit = EPGKit()
let epg = try kit.parse(data: data, format: .custom(MyCustomParser()))
```

## XMLTV Format Reference

EPGKit parses the XMLTV format by default:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tv source-info-name="My Guide">
  <channel id="bbc1.bbc.co.uk">
    <display-name lang="en">BBC One</display-name>
    <icon src="https://example.com/icon.png" width="100" height="100"/>
  </channel>
  <programme start="20240101120000 +0000"
             stop="20240101130000 +0000"
             channel="bbc1.bbc.co.uk">
    <title lang="en">The One O'Clock News</title>
    <desc lang="en">The lunchtime news bulletin.</desc>
    <category lang="en">News</category>
    <episode-num system="xmltv_ns">0.0.0/1</episode-num>
    <rating system="MPAA">
      <value>PG</value>
    </rating>
  </programme>
</tv>
```

### Date Format

XMLTV dates use the format `YYYYMMDDHHmmss TZ`:

| Example | Meaning |
|---------|---------|
| `20240101120000 +0000` | 2024-01-01 12:00:00 UTC |
| `20240101120000 +0100` | 2024-01-01 12:00:00 CET |
| `20240101120000` | No timezone — treated as UTC |
