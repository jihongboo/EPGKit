import Testing
import Foundation
@testable import EPGKit

// MARK: - Test Fixtures

private let minimalXMLTV = """
<?xml version="1.0" encoding="UTF-8"?>
<tv source-info-name="Test Guide" generator-info-name="EPGKit">
  <channel id="ch1">
    <display-name lang="en">Test Channel</display-name>
  </channel>
  <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
    <title lang="en">Test Programme</title>
  </programme>
</tv>
"""

private let fullXMLTV = """
<?xml version="1.0" encoding="UTF-8"?>
<tv source-info-url="https://example.com" source-info-name="Example Guide"
    source-data-url="https://example.com/data" generator-info-name="EPGKit/1.0"
    generator-info-url="https://github.com/example/epgkit">
  <channel id="bbc1.bbc.co.uk">
    <display-name lang="en">BBC One</display-name>
    <display-name lang="de">BBC Eins</display-name>
    <icon src="https://example.com/bbc1.png" width="100" height="100"/>
    <url>https://www.bbc.co.uk/bbcone</url>
  </channel>
  <channel id="bbc2.bbc.co.uk">
    <display-name lang="en">BBC Two</display-name>
  </channel>
  <programme start="20240101080000 +0000" stop="20240101090000 +0000" channel="bbc1.bbc.co.uk">
    <title lang="en">The Morning News</title>
    <title lang="de">Die Morgennachrichten</title>
    <sub-title lang="en">Top Stories</sub-title>
    <desc lang="en">A comprehensive morning news programme covering national and international events.</desc>
    <credits>
      <director>Jane Smith</director>
      <actor role="Anchor">John Doe</actor>
      <actor role="Reporter">Alice Brown</actor>
      <presenter>Bob Jones</presenter>
    </credits>
    <date>2024</date>
    <category lang="en">News</category>
    <category lang="de">Nachrichten</category>
    <keyword lang="en">current affairs</keyword>
    <country lang="en">UK</country>
    <language lang="en">English</language>
    <icon src="https://example.com/news.png" width="200" height="200"/>
    <episode-num system="xmltv_ns">0.0.0/1</episode-num>
    <episode-num system="onscreen">S01E01</episode-num>
    <video>
      <colour>yes</colour>
      <aspect>16:9</aspect>
      <quality>HDTV</quality>
      <present>yes</present>
    </video>
    <audio>
      <present>yes</present>
      <stereo>stereo</stereo>
    </audio>
    <rating system="MPAA">
      <value>PG</value>
      <icon src="https://example.com/rating.png"/>
    </rating>
    <star-rating system="imdb">
      <value>8/10</value>
    </star-rating>
    <subtitles type="teletext">
      <language lang="en">English</language>
    </subtitles>
    <length units="minutes">60</length>
    <new/>
  </programme>
  <programme start="20240101090000 +0000" stop="20240101100000 +0000" channel="bbc1.bbc.co.uk">
    <title lang="en">Weather Report</title>
    <previously-shown start="20231201090000 +0000" channel="bbc1.bbc.co.uk"/>
  </programme>
  <programme start="20240101100000 +0000" stop="20240101120000 +0000" channel="bbc2.bbc.co.uk">
    <title lang="en">Business Today</title>
    <category lang="en">Business</category>
    <live/>
  </programme>
</tv>
"""

private let invalidXMLTV = """
<?xml version="1.0"?>
<tv>
  <channel>
    <display-name>Channel without ID</display-name>
  </channel>
</tv>
"""

private let malformedXMLTV = """
<?xml version="1.0"?>
<tv>
  <channel id="ch1">
    <display-name>Incomplete
"""

// MARK: - EPGKit Integration Tests

@Suite("EPGKit Integration Tests")
struct EPGKitTests {

    @Test("Parse minimal XMLTV from string")
    func parseMinimalXMLTV() throws {
        let kit = EPGKit()
        let epg = try kit.parse(string: minimalXMLTV)

        #expect(epg.channelCount == 1)
        #expect(epg.programmeCount == 1)
        #expect(epg.channels.first?.id == "ch1")
        #expect(epg.programmes.first?.channelID == "ch1")
    }

    @Test("Parse full XMLTV from Data")
    func parseFromData() throws {
        let kit = EPGKit()
        let data = fullXMLTV.data(using: .utf8)!
        let epg = try kit.parse(data: data)

        #expect(epg.channelCount == 2)
        #expect(epg.programmeCount == 3)
    }

    @Test("Empty data throws emptyData error")
    func parseEmptyDataThrows() throws {
        let kit = EPGKit()
        #expect(throws: EPGError.emptyData) {
            try kit.parse(data: Data())
        }
    }

    @Test("Invalid encoding throws invalidEncoding error")
    func parseInvalidEncodingThrows() throws {
        let kit = EPGKit()
        // ASCII encoding cannot represent non-ASCII characters, returning nil data
        #expect(throws: EPGError.invalidEncoding) {
            try kit.parse(string: "\u{00e9}", encoding: .ascii)
        }
    }

    @Test("Parse from file URL asynchronously")
    func parseFromFileURL() async throws {
        let kit = EPGKit()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_epg_\(UUID().uuidString).xml")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try minimalXMLTV.write(to: tmpURL, atomically: true, encoding: .utf8)

        let epg = try await kit.parse(url: tmpURL)
        #expect(epg.channelCount == 1)
        #expect(epg.programmeCount == 1)
    }
}

// MARK: - XMLTVParser Unit Tests

@Suite("XMLTVParser Tests")
struct XMLTVParserTests {

    let parser = XMLTVParser()

    // MARK: - Channel Parsing

    @Test("Parse channel basic fields")
    func parseChannelBasic() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)

        #expect(epg.channels.count == 2)

        let ch = try #require(epg.channel(for: "bbc1.bbc.co.uk"))
        #expect(ch.id == "bbc1.bbc.co.uk")
        #expect(ch.displayNames.count == 2)
        #expect(ch.displayName == "BBC One")
        #expect(ch.displayName(for: "de") == "BBC Eins")
        #expect(ch.displayName(for: "en") == "BBC One")
        #expect(ch.url?.url.absoluteString == "https://www.bbc.co.uk/bbcone")
    }

    @Test("Parse channel icon")
    func parseChannelIcon() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)

        let ch = try #require(epg.channel(for: "bbc1.bbc.co.uk"))
        let icon = try #require(ch.icon)
        #expect(icon.src.absoluteString == "https://example.com/bbc1.png")
        #expect(icon.width == 100)
        #expect(icon.height == 100)
    }

    @Test("Missing channel ID throws error")
    func parseChannelMissingID() throws {
        #expect(throws: EPGError.missingRequiredField(field: "channel.id")) {
            try parser.parse(data: invalidXMLTV.data(using: .utf8)!)
        }
    }

    // MARK: - Programme Parsing

    @Test("Parse programme titles with multiple languages")
    func parseProgrammeTitles() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let programmes = epg.programmes(for: "bbc1.bbc.co.uk")
        let news = try #require(programmes.first)

        #expect(news.titles.count == 2)
        #expect(news.title == "The Morning News")
        #expect(news.title(for: "de") == "Die Morgennachrichten")
        #expect(news.title(for: "en") == "The Morning News")
    }

    @Test("Parse programme start and stop times")
    func parseProgrammeTime() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.duration == 3600)
        #expect(news.stop != nil)
    }

    @Test("Parse programme description")
    func parseProgrammeDescription() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.description?.isEmpty == false)
        #expect(news.descriptions.first?.language == "en")
    }

    @Test("Parse programme categories")
    func parseProgrammeCategory() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.categories.count == 2)
        #expect(news.category == "News")
    }

    @Test("Parse programme credits")
    func parseProgrammeCredits() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)
        let credits = try #require(news.credits)

        #expect(credits.directors == ["Jane Smith"])
        #expect(credits.actors.count == 2)
        #expect(credits.actors[0].name == "John Doe")
        #expect(credits.actors[0].role == "Anchor")
        #expect(credits.presenters == ["Bob Jones"])
        #expect(!credits.isEmpty)
    }

    @Test("Parse episode numbers")
    func parseProgrammeEpisodeNumber() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.episodeNumbers.count == 2)

        let xmltvNum = try #require(news.episodeNumber(for: "xmltv_ns"))
        #expect(xmltvNum.value == "0.0.0/1")

        let onscreenNum = try #require(news.episodeNumber(for: "onscreen"))
        #expect(onscreenNum.value == "S01E01")
    }

    @Test("Parse video details")
    func parseProgrammeVideo() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)
        let video = try #require(news.video)

        #expect(video.colour == true)
        #expect(video.aspect == "16:9")
        #expect(video.quality == "HDTV")
        #expect(video.present == true)
    }

    @Test("Parse audio details")
    func parseProgrammeAudio() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)
        let audio = try #require(news.audio)

        #expect(audio.present == true)
        #expect(audio.stereo == "stereo")
    }

    @Test("Parse content rating")
    func parseProgrammeRating() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.ratings.count == 1)
        let rating = news.ratings[0]
        #expect(rating.value == "PG")
        #expect(rating.system == "MPAA")
        #expect(rating.icon != nil)
    }

    @Test("Parse star rating")
    func parseProgrammeStarRating() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.starRatings.count == 1)
        let starRating = news.starRatings[0]
        #expect(starRating.value == "8/10")
        #expect(starRating.system == "imdb")
        #expect(starRating.normalizedScore == 0.8)
    }

    @Test("Parse subtitles")
    func parseProgrammeSubtitles() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.subtitles.count == 1)
        #expect(news.subtitles[0].type == "teletext")
    }

    @Test("Parse programme length")
    func parseProgrammeLength() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)
        let length = try #require(news.length)

        #expect(length.value == 60)
        #expect(length.units == "minutes")
        #expect(length.seconds == 3600)
    }

    @Test("Parse isNew flag")
    func parseProgrammeIsNew() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)

        #expect(news.isNew == true)
    }

    @Test("Parse isLive flag")
    func parseProgrammeIsLive() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let business = try #require(epg.programmes(for: "bbc2.bbc.co.uk").first)

        #expect(business.isLive == true)
    }

    @Test("Parse previously-shown element")
    func parseProgrammePreviouslyShown() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let weather = try #require(epg.programmes(for: "bbc1.bbc.co.uk").last)
        let prev = try #require(weather.previouslyShown)

        #expect(prev.channel == "bbc1.bbc.co.uk")
        #expect(prev.start != nil)
    }

    @Test("Parse programme icon")
    func parseProgrammeIcon() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let news = try #require(epg.programmes(for: "bbc1.bbc.co.uk").first)
        let icon = try #require(news.icon)

        #expect(icon.src.absoluteString == "https://example.com/news.png")
        #expect(icon.width == 200)
        #expect(icon.height == 200)
    }

    @Test("Parse source info from tv element")
    func parseSourceInfo() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let info = try #require(epg.sourceInfo)

        #expect(info.sourceInfoName == "Example Guide")
        #expect(info.sourceInfoURL?.absoluteString == "https://example.com")
        #expect(info.generatorInfoName == "EPGKit/1.0")
    }

    @Test("Malformed XML throws xmlParsingFailed")
    func parseMalformedXML() throws {
        let data = malformedXMLTV.data(using: .utf8)!
        #expect {
            try parser.parse(data: data)
        } throws: { error in
            if case EPGError.xmlParsingFailed = error { return true }
            return false
        }
    }

    @Test("Programmes are sorted by start time")
    func programmesAreSorted() throws {
        let epg = try parser.parse(data: fullXMLTV.data(using: .utf8)!)
        let programmes = epg.programmes(for: "bbc1.bbc.co.uk")

        let dates = programmes.map(\.start)
        #expect(dates == dates.sorted())
    }
}

// MARK: - EPGData Query Tests

@Suite("EPGData Query Tests")
struct EPGDataQueryTests {

    var epg: EPGData {
        get throws {
            try XMLTVParser().parse(data: fullXMLTV.data(using: .utf8)!)
        }
    }

    @Test("Query programmes by channel ID")
    func queryProgrammesByChannelID() throws {
        let epg = try epg
        let programmes = epg.programmes(for: "bbc1.bbc.co.uk")
        #expect(programmes.count == 2)
        #expect(programmes.allSatisfy { $0.channelID == "bbc1.bbc.co.uk" })
    }

    @Test("Non-existent channel returns empty array")
    func queryNonExistentChannel() throws {
        let epg = try epg
        #expect(epg.programmes(for: "nonexistent").isEmpty)
    }

    @Test("Query programmes within a date range")
    func queryProgrammesInDateRange() throws {
        let epg = try epg
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        let start = try #require(formatter.date(from: "20240101080000 +0000"))
        let end = try #require(formatter.date(from: "20240101093000 +0000"))

        let programmes = epg.programmes(in: start...end)
        #expect(programmes.count == 2)
    }

    @Test("Query current programme for a channel")
    func queryCurrentProgramme() throws {
        let epg = try epg
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"

        let queryTime = try #require(formatter.date(from: "20240101083000 +0000"))
        let current = epg.currentProgramme(for: "bbc1.bbc.co.uk", at: queryTime)

        #expect(current?.title == "The Morning News")
    }

    @Test("Query before schedule returns nil")
    func queryCurrentProgrammeOutOfRange() throws {
        let epg = try epg
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"

        let queryTime = try #require(formatter.date(from: "20240101060000 +0000"))
        let current = epg.currentProgramme(for: "bbc1.bbc.co.uk", at: queryTime)

        #expect(current == nil)
    }

    @Test("Query next programme after a given time")
    func queryNextProgramme() throws {
        let epg = try epg
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"

        let queryTime = try #require(formatter.date(from: "20240101083000 +0000"))
        let next = epg.nextProgramme(for: "bbc1.bbc.co.uk", after: queryTime)

        #expect(next?.title == "Weather Report")
    }

    @Test("Query current programmes across all channels")
    func queryAllCurrentProgrammes() throws {
        let epg = try epg
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"

        let queryTime = try #require(formatter.date(from: "20240101103000 +0000"))
        let current = epg.currentProgrammes(at: queryTime)

        #expect(current["bbc2.bbc.co.uk"]?.title == "Business Today")
    }

    @Test("Statistics are accurate")
    func queryStatistics() throws {
        let epg = try epg
        #expect(epg.channelCount == 2)
        #expect(epg.programmeCount == 3)
        #expect(epg.earliestDate != nil)
        #expect(epg.latestDate != nil)
    }

    @Test("Look up channel by ID")
    func queryChannelByID() throws {
        let epg = try epg
        let ch = epg.channel(for: "bbc1.bbc.co.uk")
        #expect(ch?.displayName == "BBC One")
    }
}

// MARK: - Supporting Type Tests

@Suite("Supporting Type Tests")
struct SupportingTypeTests {

    @Test("LocalizedString string literal initialisation")
    func localizedStringLiteral() {
        let s: LocalizedString = "Hello"
        #expect(s.value == "Hello")
        #expect(s.language == nil)
    }

    @Test("EpisodeNumber xmltv_ns component parsing")
    func episodeNumberParsing() {
        let ep = EpisodeNumber(value: "1.2.0/1", system: "xmltv_ns")
        let components = ep.xmltvComponents

        #expect(components?.season == 2)
        #expect(components?.episode == 3)
    }

    @Test("StarRating normalised score")
    func starRatingNormalized() {
        let rating = StarRating(value: "7/10")
        #expect(rating.normalizedScore == 0.7)

        let perfect = StarRating(value: "5/5")
        #expect(perfect.normalizedScore == 1.0)
    }

    @Test("StarRating invalid format returns nil")
    func starRatingInvalidFormat() {
        let rating = StarRating(value: "invalid")
        #expect(rating.normalizedScore == nil)
    }

    @Test("Length unit conversion to seconds")
    func lengthConversion() {
        let hours = Length(value: 2, units: "hours")
        #expect(hours.seconds == 7200)

        let minutes = Length(value: 90, units: "minutes")
        #expect(minutes.seconds == 5400)

        let seconds = Length(value: 3600, units: "seconds")
        #expect(seconds.seconds == 3600)
    }

    @Test("Programme conforms to Identifiable")
    func programmeIdentifiable() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        let start = try #require(formatter.date(from: "20240101080000 +0000"))

        let p = Programme(channelID: "ch1", start: start, titles: ["News"])
        #expect(!p.id.isEmpty)
        #expect(p.id.contains("ch1"))
    }

    @Test("Credits isEmpty")
    func creditsIsEmpty() {
        let empty = Credits()
        #expect(empty.isEmpty)

        let nonEmpty = Credits(directors: ["A Director"])
        #expect(!nonEmpty.isEmpty)
    }

    @Test("EPGError localised description contains context")
    func epgErrorLocalization() {
        let error = EPGError.missingRequiredField(field: "channel.id")
        #expect(error.errorDescription?.contains("channel.id") == true)

        let parseError = EPGError.xmlParsingFailed(reason: "test reason")
        #expect(parseError.errorDescription?.contains("test reason") == true)
    }

    @Test("EPGError Equatable conformance")
    func epgErrorEquatable() {
        #expect(EPGError.emptyData == EPGError.emptyData)
        #expect(EPGError.invalidEncoding == EPGError.invalidEncoding)
        #expect(EPGError.emptyData != EPGError.invalidEncoding)
        #expect(
            EPGError.missingRequiredField(field: "id") ==
            EPGError.missingRequiredField(field: "id")
        )
        #expect(
            EPGError.missingRequiredField(field: "id") !=
            EPGError.missingRequiredField(field: "name")
        )
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
struct EdgeCaseTests {

    let parser = XMLTVParser()

    @Test("Channel with no programmes")
    func channelWithNoProgrammes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="empty">
            <display-name>Empty Channel</display-name>
          </channel>
        </tv>
        """
        let epg = try parser.parse(data: xml.data(using: .utf8)!)
        #expect(epg.channelCount == 1)
        #expect(epg.programmes(for: "empty").isEmpty)
    }

    @Test("Programme without stop time")
    func programmeWithoutStopTime() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="ch1"><display-name>Channel</display-name></channel>
          <programme start="20240101120000 +0000" channel="ch1">
            <title>Open-ended Programme</title>
          </programme>
        </tv>
        """
        let epg = try parser.parse(data: xml.data(using: .utf8)!)
        let p = try #require(epg.programmes.first)

        #expect(p.stop == nil)
        #expect(p.duration == nil)
    }

    @Test("XMLTV date without timezone is treated as UTC")
    func dateWithoutTimezone() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="ch1"><display-name>Channel</display-name></channel>
          <programme start="20240101120000" stop="20240101130000" channel="ch1">
            <title>UTC Programme</title>
          </programme>
        </tv>
        """
        let epg = try parser.parse(data: xml.data(using: .utf8)!)
        let p = try #require(epg.programmes.first)

        #expect(p.duration == 3600)
    }

    @Test("Multi-channel programmes sorted globally by start time")
    func multiChannelProgrammeOrder() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="a"><display-name>A</display-name></channel>
          <channel id="b"><display-name>B</display-name></channel>
          <programme start="20240101130000 +0000" stop="20240101140000 +0000" channel="a">
            <title>A Afternoon</title>
          </programme>
          <programme start="20240101080000 +0000" stop="20240101090000 +0000" channel="b">
            <title>B Morning</title>
          </programme>
          <programme start="20240101090000 +0000" stop="20240101100000 +0000" channel="a">
            <title>A Morning</title>
          </programme>
        </tv>
        """
        let epg = try parser.parse(data: xml.data(using: .utf8)!)

        #expect(epg.programmes[0].title == "B Morning")
        #expect(epg.programmes[1].title == "A Morning")
        #expect(epg.programmes[2].title == "A Afternoon")

        let channelA = epg.programmes(for: "a")
        #expect(channelA[0].title == "A Morning")
        #expect(channelA[1].title == "A Afternoon")
    }

    @Test("Missing programme start attribute throws error")
    func missingProgrammeStartThrows() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="ch1"><display-name>Channel</display-name></channel>
          <programme channel="ch1">
            <title>No Start</title>
          </programme>
        </tv>
        """
        #expect(throws: EPGError.missingRequiredField(field: "programme.start")) {
            try parser.parse(data: xml.data(using: .utf8)!)
        }
    }

    @Test("Date range query includes boundary start times")
    func dateRangeQueryPrecision() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="ch1"><display-name>Channel</display-name></channel>
          <programme start="20240101080000 +0000" stop="20240101090000 +0000" channel="ch1">
            <title>Morning Show</title>
          </programme>
          <programme start="20240101090000 +0000" stop="20240101100000 +0000" channel="ch1">
            <title>Late Morning Show</title>
          </programme>
          <programme start="20240101200000 +0000" stop="20240101210000 +0000" channel="ch1">
            <title>Evening Show</title>
          </programme>
        </tv>
        """
        let epg = try parser.parse(data: xml.data(using: .utf8)!)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        let start = try #require(formatter.date(from: "20240101080000 +0000"))
        let end = try #require(formatter.date(from: "20240101090000 +0000"))

        let result = epg.programmes(in: start...end)
        #expect(result.count == 2)
    }
}

// MARK: - Official XMLTV Test Fixture
//
// Derived from the official XMLTV project test data at:
// https://github.com/XMLTV/xmltv/blob/master/t/data/test.xml
// This exercises every element and attribute defined in the XMLTV DTD.

private let officialTestXMLTV = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">

<tv generator-info-name="my listings generator">
  <channel id="3sat.de">
    <display-name lang="de">3SAT</display-name>
    <url>https://www.3sat.de</url>
    <url system="imdb">https://www.imdb.com/3sat</url>
  </channel>
  <channel id="das-erste.de">
    <display-name lang="de">ARD</display-name>
    <display-name lang="de">Das Erste</display-name>
  </channel>
  <programme start="200006031633" channel="3sat.de"
             pdc-start="200006031630" showview="12345" videoplus="67890" clumpidx="0/1">
    <title lang="de">Blah</title>
    <title lang="en">Blah</title>
    <sub-title lang="en">Episode One</sub-title>
    <desc lang="de">Blah Blah Blah.</desc>
    <credits>
      <director>Jane Director</director>
      <actor>a</actor>
      <actor>b</actor>
      <actor role="blah">c</actor>
      <actor guest="yes">d</actor>
      <actor role="hero">e
        <image type="person">https://www.example.com/actor.jpg</image>
        <url system="TMDB">https://www.themoviedb.org/person/204</url>
      </actor>
      <writer>Some Writer</writer>
      <producer>Some Producer</producer>
    </credits>
    <date>19901011</date>
    <category lang="en">Comedy</category>
    <keyword lang="en">funny</keyword>
    <language lang="en">English</language>
    <orig-language lang="en">German</orig-language>
    <length units="minutes">60</length>
    <icon src="https://image.example.com/poster.jpg" width="500" height="123"/>
    <url>https://www.example.com/title/0365/</url>
    <url system="IMDb">https://www.example.com/title/tt0365/</url>
    <country>ES</country>
    <country lang="en">Spain</country>
    <episode-num system="xmltv_ns">2 . 9 . 0/1</episode-num>
    <episode-num system="onscreen">S03E10</episode-num>
    <video>
      <present>yes</present>
      <colour>yes</colour>
      <aspect>16:9</aspect>
      <quality>HDTV</quality>
    </video>
    <audio>
      <present>yes</present>
      <stereo>stereo</stereo>
    </audio>
    <previously-shown start="199905120000" channel="das-erste.de"/>
    <premiere lang="en">First airing in Germany</premiere>
    <last-chance lang="en">Last showing tonight</last-chance>
    <new/>
    <subtitles type="teletext">
      <language lang="en">English</language>
    </subtitles>
    <rating system="MPAA">
      <value>PG</value>
      <icon src="https://example.com/pg.png"/>
    </rating>
    <star-rating system="imdb">
      <value>3/3</value>
      <icon src="https://example.com/stars.png"/>
    </star-rating>
    <review type="text" source="tvreviews" reviewer="joe" lang="en">More blah blah</review>
    <review type="url" source="imdb" lang="en">https://www.imdb.com/review/rw123</review>
    <image>https://www.example.com/still.jpg</image>
    <image type="backdrop" size="2" system="tmdb">https://www.example.com/backdrop.jpg</image>
    <image type="poster" size="2" orient="L" system="tmdb">https://www.example.com/poster.jpg</image>
  </programme>
</tv>
"""

// MARK: - Official XMLTV Spec Compliance Tests

@Suite("XMLTV Spec Compliance Tests")
struct XMLTVSpecComplianceTests {

    let parser = XMLTVParser()

    private func parseOfficial() throws -> EPGData {
        try parser.parse(data: officialTestXMLTV.data(using: .utf8)!)
    }

    // MARK: Channel

    @Test("Channel url with system attribute")
    func channelUrlWithSystem() throws {
        let epg = try parseOfficial()
        let ch = try #require(epg.channel(for: "3sat.de"))
        #expect(ch.urls.count == 2)
        #expect(ch.urls[0].url.absoluteString == "https://www.3sat.de")
        #expect(ch.urls[0].system == nil)
        #expect(ch.urls[1].url.absoluteString == "https://www.imdb.com/3sat")
        #expect(ch.urls[1].system == "imdb")
    }

    @Test("Channel multiple display names")
    func channelMultipleDisplayNames() throws {
        let epg = try parseOfficial()
        let ch = try #require(epg.channel(for: "das-erste.de"))
        #expect(ch.displayNames.count == 2)
        #expect(ch.displayNames[0].value == "ARD")
        #expect(ch.displayNames[1].value == "Das Erste")
    }

    // MARK: Programme attributes

    @Test("Programme pdc-start, showview, videoplus, clumpidx attributes")
    func programmeProgrammeAttributes() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.pdcStart != nil)
        #expect(p.showview == "12345")
        #expect(p.videoplus == "67890")
        #expect(p.clumpIndex == "0/1")
    }

    // MARK: Programme children

    @Test("Programme multiple titles with language")
    func programmeTitles() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.titles.count == 2)
        #expect(p.title(for: "de") == "Blah")
        #expect(p.title(for: "en") == "Blah")
    }

    @Test("Programme sub-title")
    func programmeSubTitle() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.subTitles.count == 1)
        #expect(p.subTitles[0].value == "Episode One")
    }

    @Test("Programme date field")
    func programmeDate() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.date == "19901011")
    }

    @Test("Programme language and orig-language")
    func programmeLanguage() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.language?.value == "English")
        #expect(p.originalLanguage?.value == "German")
    }

    @Test("Programme multiple countries")
    func programmeCountries() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.countries.count == 2)
        #expect(p.countries[0].value == "ES")
        #expect(p.countries[1].value == "Spain")
        #expect(p.countries[1].language == "en")
    }

    @Test("Programme url elements with system attribute")
    func programmeUrls() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.urls.count == 2)
        #expect(p.urls[0].url.absoluteString == "https://www.example.com/title/0365/")
        #expect(p.urls[0].system == nil)
        #expect(p.urls[1].url.absoluteString == "https://www.example.com/title/tt0365/")
        #expect(p.urls[1].system == "IMDb")
    }

    @Test("Programme multiple episode-num systems")
    func programmeEpisodeNumbers() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.episodeNumbers.count == 2)
        let xmltvNs = try #require(p.episodeNumber(for: "xmltv_ns"))
        let components = try #require(xmltvNs.xmltvComponents)
        #expect(components.season == 3)   // 2 (zero-based) + 1
        #expect(components.episode == 10) // 9 (zero-based) + 1
    }

    @Test("Programme previously-shown with start and channel")
    func programmePreviouslyShown() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let ps = try #require(p.previouslyShown)
        #expect(ps.start != nil)
        #expect(ps.channel == "das-erste.de")
    }

    @Test("Programme premiere with text and lang")
    func programmePremiere() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let premiere = try #require(p.premiere)
        #expect(premiere.value == "First airing in Germany")
        #expect(premiere.language == "en")
    }

    @Test("Programme last-chance with text and lang")
    func programmeLastChance() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let lc = try #require(p.lastChance)
        #expect(lc.value == "Last showing tonight")
        #expect(lc.language == "en")
    }

    @Test("Programme isNew flag")
    func programmeIsNew() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.isNew == true)
    }

    // MARK: Credits

    @Test("Credits actors with role and guest attributes")
    func creditsActors() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let credits = try #require(p.credits)
        #expect(credits.directors == ["Jane Director"])
        #expect(credits.writers == ["Some Writer"])
        #expect(credits.producers == ["Some Producer"])
        #expect(credits.actors.count == 5)

        // actor "a" — no role, no guest
        #expect(credits.actors[0].name == "a")
        #expect(credits.actors[0].role == nil)
        #expect(credits.actors[0].guest == false)

        // actor with role="blah"
        #expect(credits.actors[2].name == "c")
        #expect(credits.actors[2].role == "blah")

        // actor with guest="yes"
        #expect(credits.actors[3].name == "d")
        #expect(credits.actors[3].guest == true)

        // actor with child <image> and <url>
        let actorE = credits.actors[4]
        #expect(actorE.name == "e")
        #expect(actorE.role == "hero")
        #expect(actorE.image?.type == .person)
        #expect(actorE.image?.src.absoluteString == "https://www.example.com/actor.jpg")
        #expect(actorE.url?.system == "TMDB")
        #expect(actorE.url?.url.absoluteString == "https://www.themoviedb.org/person/204")
    }

    // MARK: Ratings and star-ratings

    @Test("Rating with value and icon")
    func ratingWithIcon() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let rating = try #require(p.ratings.first)
        #expect(rating.system == "MPAA")
        #expect(rating.value == "PG")
        #expect(rating.icon?.src.absoluteString == "https://example.com/pg.png")
    }

    @Test("Star-rating with value and icon")
    func starRatingWithIcon() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let sr = try #require(p.starRatings.first)
        #expect(sr.system == "imdb")
        #expect(sr.value == "3/3")
        #expect(sr.normalizedScore == 1.0)
        #expect(sr.icon?.src.absoluteString == "https://example.com/stars.png")
    }

    // MARK: Reviews

    @Test("Review text type with metadata")
    func reviewText() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.reviews.count == 2)

        let textReview = p.reviews[0]
        #expect(textReview.type == .text)
        #expect(textReview.content == "More blah blah")
        #expect(textReview.source == "tvreviews")
        #expect(textReview.reviewer == "joe")
        #expect(textReview.language == "en")
    }

    @Test("Review url type")
    func reviewUrl() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let urlReview = p.reviews[1]
        #expect(urlReview.type == .url)
        #expect(urlReview.content == "https://www.imdb.com/review/rw123")
        #expect(urlReview.source == "imdb")
    }

    // MARK: Images

    @Test("Programme images with type, size, orient, system")
    func programmeImages() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        #expect(p.images.count == 3)

        // Plain image (no attributes)
        #expect(p.images[0].src.absoluteString == "https://www.example.com/still.jpg")
        #expect(p.images[0].type == nil)

        // Backdrop image
        let backdrop = p.images[1]
        #expect(backdrop.type == .backdrop)
        #expect(backdrop.size == .medium)
        #expect(backdrop.system == "tmdb")

        // Poster image with orientation
        let poster = p.images[2]
        #expect(poster.type == .poster)
        #expect(poster.orient == .landscape)
        #expect(poster.size == .medium)
        #expect(poster.system == "tmdb")
    }

    // MARK: Video and Audio

    @Test("Video details — colour, aspect, quality, present")
    func videoDetails() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let video = try #require(p.video)
        #expect(video.colour == true)
        #expect(video.aspect == "16:9")
        #expect(video.quality == "HDTV")
        #expect(video.present == true)
    }

    @Test("Audio details — present and stereo")
    func audioDetails() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let audio = try #require(p.audio)
        #expect(audio.present == true)
        #expect(audio.stereo == "stereo")
    }

    // MARK: Subtitles

    @Test("Subtitle type and language")
    func subtitleTypeAndLanguage() throws {
        let epg = try parseOfficial()
        let p = try #require(epg.programmes.first)
        let sub = try #require(p.subtitles.first)
        #expect(sub.type == "teletext")
        #expect(sub.language?.value == "English")
        #expect(sub.language?.language == "en")
    }

    // MARK: EPGUrl

    @Test("EPGUrl equality and hashability")
    func epgUrlEquality() throws {
        let url = URL(string: "https://example.com")!
        let a = EPGUrl(url: url, system: "imdb")
        let b = EPGUrl(url: url, system: "imdb")
        let c = EPGUrl(url: url, system: nil)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }
}
