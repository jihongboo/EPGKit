# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a single test by name
swift test --filter "EPGKitTests/testName"

# Run a specific suite
swift test --filter "XMLTV Spec Compliance Tests"

# Build DocC locally
swift package --allow-writing-to-directory ./docs \
  generate-documentation \
  --target EPGKit \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path EPGKit \
  --output-path ./docs
```

## Architecture

**EPGKit** is a Swift 6 SPM library. Entry point is `EPGKit` (a `Sendable` struct). The data flow is:

```
EPGKit.parse(url/data/string)
  → EPGParser protocol (XMLTVParser or custom)
  → EPGData (channels + programmes + lookup indexes)
```

### Key files

- `Sources/EPGKit/EPGKit.swift` — Public API. Thin wrapper that selects a parser and calls `parse(data:)`.
- `Sources/EPGKit/Parsers/EPGParser.swift` — `EPGParser` protocol + `EPGFormat` enum.
- `Sources/EPGKit/Parsers/XMLTVParser.swift` — SAX parser built on `Foundation.XMLParser`. Uses internal builder classes (`ProgrammeBuilder`, `ActorBuilder`, etc.) as mutable accumulation state during parsing.
- `Sources/EPGKit/Models/EPGData.swift` — Result type. Builds `channelIndex` and `programmeIndex` (both `[String: ...]`) at init time for O(1) lookups.
- `Sources/EPGKit/Models/Programme.swift` — Full XMLTV programme model.
- `Sources/EPGKit/Models/Channel.swift` — Channel model.
- `Sources/EPGKit/Models/Supporting.swift` — All supporting types: `LocalizedString`, `Icon`, `EPGUrl`, `EPGImage`, `Actor`, `Credits`, `Rating`, `StarRating`, `EpisodeNumber`, `Video`, `Audio`, `Subtitle`, `Review`, `Length`, `SourceInfo`, `PreviouslyShown`.

### SAX parsing notes

`XMLTVParser` uses SAX (event-driven) parsing via `NSXMLParser`. Important patterns to be aware of:

- `currentText` is reset in `didStartElement` and read in `didEndElement` — only valid for simple text nodes.
- **Mixed-content elements** (e.g. `<actor>` with child `<image>` and `<url>`): `currentText` is wiped when a child element starts. The actor name is accumulated separately in `ActorBuilder.nameBuffer` via `foundCharacters` when `currentElement == "actor"`.
- `insideSubtitles: Bool` flag is used to route `<language>` to the subtitle builder rather than `programme.language`.
- URL elements are routed by context: actor → `actorBuilder?.url`, channel → `currentChannelURLs`, programme → `currentProgramme?.urls`.

### EPGUrl vs URL

`EPGUrl` wraps `URL` + `system: String?` to carry the `system` attribute from `<url system="...">`. Use `epgUrl.url` to get the underlying `URL`.

## Testing

Tests use **Swift Testing** (`@Suite`, `@Test`, `#expect`, `#require`) in `Tests/EPGKitTests/EPGKitTests.swift`. 6 suites covering parsing, querying, spec compliance, and edge cases.

## CI/CD

- `.github/workflows/ci.yml` — Runs `swift test` on push/PR to `main`.
- `.github/workflows/docc.yml` — Builds and deploys DocC to GitHub Pages on push to `main`.
- `.github/workflows/release.yml` — Creates GitHub Releases; supports manual trigger with version input or auto-trigger on tag push.

All workflows use `maxim-lobanov/setup-xcode@v1` with `xcode-version: latest-stable`.
