# EPGKit

[![CI](https://github.com/jihongboo/EPGKit/actions/workflows/ci.yml/badge.svg)](https://github.com/jihongboo/EPGKit/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen?logo=swift)](https://swift.org/package-manager)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%20%7C%20macOS%2013%20%7C%20tvOS%2016%20%7C%20watchOS%209%20%7C%20visionOS%201-blue)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

A Swift 6 package for parsing XMLTV-format EPG data into fully-typed Swift models, with complete spec coverage, O(1) channel/programme lookups, and a comprehensive test suite.

## Requirements

- Swift 6.2+
- iOS 16+ / macOS 13+ / tvOS 16+ / watchOS 9+ / visionOS 1+

## Installation

Add EPGKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jihongboo/EPGKit.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["EPGKit"]),
]
```

## Quick Start

```swift
import EPGKit

let kit = EPGKit()

// From a URL (local or remote)
let epg = try await kit.parse(url: URL(string: "https://example.com/epg.xml")!)

// From Data or String
let epg = try kit.parse(data: data)
let epg = try kit.parse(string: xmlString)
```

## Querying

```swift
// Channel lookup
let channel = epg.channel(for: "bbc1.bbc.co.uk")

// Currently airing
let current = epg.currentProgramme(for: "bbc1.bbc.co.uk")
let allCurrent = epg.currentProgrammes(at: Date())

// What's next
let next = epg.nextProgramme(for: "bbc1.bbc.co.uk", after: Date())

// Time range
let programmes = epg.programmes(for: "bbc1.bbc.co.uk", in: startDate...endDate)
```

## Models

| Model | Description |
|-------|-------------|
| `EPGData` | Parsed result containing channels and programmes |
| `Channel` | Channel with display names, icons, and URLs |
| `Programme` | Full programme with all XMLTV fields |
| `Credits` | Cast and crew (director, actor, writer, …) |
| `Actor` | Actor with role, guest flag, image, and URL |
| `Rating` | Content rating (MPAA, FSK, …) |
| `StarRating` | Quality rating with normalised score |
| `EpisodeNumber` | Episode number with `xmltv_ns` component parsing |
| `EPGImage` | Image with type, size, orientation, and system |
| `EPGUrl` | URL with optional source system identifier |
| `Review` | Text or URL review with source and reviewer |
| `Video` / `Audio` | Format details |
| `Subtitle` | Subtitle track with type and language |
| `Length` | Programme duration with unit conversion |

## XMLTV Spec Coverage

EPGKit implements the complete [XMLTV DTD](https://github.com/XMLTV/xmltv/blob/master/xmltv.dtd):

- All `<tv>` root attributes (`date`, `source-info-*`, `generator-info-*`)
- All `<channel>` child elements including multiple `<icon>` and `<url system="...">`
- All `<programme>` attributes (`start`, `stop`, `pdc-start`, `vps-start`, `showview`, `videoplus`, `clumpidx`)
- All 25 `<programme>` child elements in spec order
- `<actor guest="yes">` with `<image>` and `<url>` child elements
- `<url system="...">` on channels, programmes, and credits members
- `<last-chance>` and `<premiere>` as localised strings

## Custom Parsers

```swift
struct MyParser: EPGParser {
    func parse(data: Data) throws -> EPGData {
        // custom parsing logic
        return EPGData(channels: [], programmes: [])
    }
}

let epg = try kit.parse(data: data, format: .custom(MyParser()))
```

## License

MIT
