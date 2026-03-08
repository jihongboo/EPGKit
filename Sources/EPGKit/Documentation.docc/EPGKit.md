# ``EPGKit``

A Swift 6 Electronic Program Guide (EPG) parsing framework for all Apple platforms.

## Overview

EPGKit provides a concise, type-safe API for parsing EPG data. It is fully compatible
with Swift 6 strict concurrency and supports iOS, macOS, tvOS, watchOS, and visionOS.

### Supported Formats

| Format | Description |
|--------|-------------|
| XMLTV  | The most widely used open EPG format, based on XML |
| Custom | Any format, by implementing the ``EPGParser`` protocol |

### Quick Start

**Parse from a remote URL:**

```swift
let kit = EPGKit()
let epg = try await kit.parse(url: URL(string: "https://example.com/epg.xml")!)

print("\(epg.channelCount) channels, \(epg.programmeCount) programmes")

// What is on right now across all channels
let nowPlaying = epg.currentProgrammes(at: Date())
```

**Parse from local data:**

```swift
let kit = EPGKit()
let data = try Data(contentsOf: localFileURL)
let epg = try kit.parse(data: data)
```

**Query the schedule:**

```swift
// All programmes for a channel
let programmes = epg.programmes(for: "bbc1.bbc.co.uk")

// Currently airing
let current = epg.currentProgramme(for: "bbc1.bbc.co.uk")

// Next programme
let next = epg.nextProgramme(for: "bbc1.bbc.co.uk")

// Today's schedule
let start = Calendar.current.startOfDay(for: Date())
let end = start.addingTimeInterval(86400)
let today = epg.programmes(for: "bbc1.bbc.co.uk", in: start...end)
```

## Topics

### Entry Point

- ``EPGKit``

### Data Models

- ``EPGData``
- ``Channel``
- ``Programme``
- ``SourceInfo``

### Supporting Types

- ``LocalizedString``
- ``Icon``
- ``EpisodeNumber``
- ``Credits``
- ``Actor``
- ``Rating``
- ``StarRating``
- ``Video``
- ``Audio``
- ``Subtitle``
- ``Length``
- ``PreviouslyShown``

### Parsers

- ``EPGParser``
- ``XMLTVParser``
- ``EPGFormat``

### Errors

- ``EPGError``
