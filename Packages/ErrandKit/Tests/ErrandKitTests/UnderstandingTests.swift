import Foundation
import Testing
@testable import ErrandKit

@Suite struct HeuristicErrandParserTests {
    @Test func understandsTheEverydayExample() {
        let errands = HeuristicErrandParser.parse(
            "Today I need to go to the store and go grocery shopping, I need to stop off at CVS to pick up my medication, and I need to pick my kids up from school"
        )

        #expect(errands.map(\.title) == ["Go grocery shopping", "Pick up my medication", "Pick my kids up from school"])
        #expect(errands.map(\.placeQuery) == ["the store", "CVS", "school"])
        #expect(errands.map(\.durationMinutes) == [35, 10, 10])
    }

    @Test func readsFixedTimes() {
        let errands = HeuristicErrandParser.parse("pick up the kids at 3, then dentist at 10:30 am, gym by 6:15pm")

        #expect(errands.map(\.fixedTime) == [
            ClockTime(hour: 15, minute: 0),
            ClockTime(hour: 10, minute: 30),
            ClockTime(hour: 18, minute: 15)
        ])
        #expect(errands[0].placeQuery == "school")
        #expect(errands[0].title == "Pick up the kids")
    }

    @Test func activityAfterToIsNotAPlace() {
        let errands = HeuristicErrandParser.parse("go to pick up dry cleaning")

        #expect(errands.count == 1)
        #expect(errands[0].placeQuery == "dry cleaner")
        #expect(errands[0].durationMinutes == 5)
    }

    @Test func unknownErrandGetsDefaults() {
        let errands = HeuristicErrandParser.parse("return library books")

        #expect(errands.count == 1)
        #expect(errands[0].title == "Return library books")
        #expect(errands[0].placeQuery == nil)
        #expect(errands[0].durationMinutes == 15)
    }

    @Test func ignoresEmptyInput() {
        #expect(HeuristicErrandParser.parse("").isEmpty)
        #expect(HeuristicErrandParser.parse("today, and then").isEmpty)
    }

    @Test func clockTimeParsesModelOutput() {
        #expect(ClockTime(hhmm: "15:00") == ClockTime(hour: 15, minute: 0))
        #expect(ClockTime(hhmm: "") == nil)
        #expect(ClockTime(hhmm: "25:00") == nil)
    }
}

@Suite struct PlaceResolverTests {
    let kroger = PlaceRef(name: "Kroger", latitude: 1, longitude: 1)
    let cvs = PlaceRef(name: "CVS Pharmacy", latitude: 2, longitude: 2)
    let otherCVS = PlaceRef(name: "CVS Pharmacy", latitude: 3, longitude: 3)
    let school = PlaceRef(name: "Lincoln Elementary", latitude: 4, longitude: 4)

    var known: [KnownPlace] {
        [
            KnownPlace(place: kroger, nickname: "the store", useCount: 5),
            KnownPlace(place: otherCVS, useCount: 1),
            KnownPlace(place: cvs, useCount: 9),
            KnownPlace(place: school, nickname: "school", useCount: 20)
        ]
    }

    @Test func matchesNicknames() {
        #expect(PlaceResolver.match("the store", in: known) == kroger)
        #expect(PlaceResolver.match("my store", in: known) == kroger)
        #expect(PlaceResolver.match("School", in: known) == school)
    }

    @Test func matchesNamesPreferringMostUsed() {
        #expect(PlaceResolver.match("CVS", in: known) == cvs)
        #expect(PlaceResolver.match("cvs pharmacy", in: known) == cvs)
    }

    @Test func returnsNilForUnknownPlaces() {
        #expect(PlaceResolver.match("Target", in: known) == nil)
        #expect(PlaceResolver.match("at", in: known) == nil)
    }

    @Test func recognisesNicknamePhrases() {
        #expect(PlaceResolver.isNickname("the store"))
        #expect(PlaceResolver.isNickname("My gym"))
        #expect(!PlaceResolver.isNickname("CVS"))
    }
}

@Suite struct MentionedTimeTests {
    @Test func findsSpokenTimes() {
        let times = ClockTime.mentioned(in: "pick up the kids from school at 3 and the dentist at 10:30 am")
        #expect(times.contains(ClockTime(hour: 15, minute: 0)))
        #expect(times.contains(ClockTime(hour: 3, minute: 0)))
        #expect(times.contains(ClockTime(hour: 10, minute: 30)))
        #expect(!times.contains(ClockTime(hour: 22, minute: 30)))
    }

    @Test func readsWordsAndNoon() {
        let times = ClockTime.mentioned(in: "lunch at noon, gym at five, call around 6pm")
        #expect(times.contains(ClockTime(hour: 12, minute: 0)))
        #expect(times.contains(ClockTime(hour: 17, minute: 0)))
        #expect(times.contains(ClockTime(hour: 18, minute: 0)))
    }

    @Test func noTimeMeansNone() {
        #expect(ClockTime.mentioned(in: "go to the store and pick up my meds at CVS").isEmpty)
    }

    @Test func roundTripsThroughMinutes() {
        let time = ClockTime(hour: 15, minute: 45)
        #expect(ClockTime(minutesSinceMidnight: time.minutesSinceMidnight) == time)
    }
}

@Suite struct DurationTextTests {
    @Test func formatsMinutesAndHours() {
        #expect(DurationText.format(minutes: 45) == "45 min")
        #expect(DurationText.format(minutes: 60) == "1 hr")
        #expect(DurationText.format(minutes: 75) == "1 hr 15 min")
        #expect(DurationText.format(minutes: 240) == "4 hr")
    }
}
