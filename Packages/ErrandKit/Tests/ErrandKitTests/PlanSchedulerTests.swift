import Foundation
import Testing
@testable import ErrandKit

/// Travel times from a fixed table, in minutes; unknown pairs take 10 minutes.
struct TableTravel: TravelTimes {
    var minutes: [String: Double]

    func travelTime(from origin: PlaceRef, to destination: PlaceRef) -> TimeInterval {
        let key = "\(origin.name)>\(destination.name)"
        return (minutes[key] ?? 10) * 60
    }
}

let day = Date(timeIntervalSince1970: 1_800_000_000) // a fixed reference time
func at(_ minutes: Double) -> Date { day.addingTimeInterval(minutes * 60) }

let home = PlaceRef(name: "Home", latitude: 0, longitude: 0)
let cvs = PlaceRef(name: "CVS", latitude: 0, longitude: 1)
let store = PlaceRef(name: "Store", latitude: 0, longitude: 2)
let school = PlaceRef(name: "School", latitude: 0, longitude: 3)

@Suite struct PlanSchedulerTests {
    @Test func timesStopsInOrder() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: ["Home>CVS": 5, "CVS>Store": 8]))
        let stops = [
            PlanStop(title: "Pick up meds", place: cvs, duration: 10 * 60),
            PlanStop(title: "Groceries", place: store, duration: 30 * 60)
        ]
        let plan = scheduler.timeline(from: home, startingAt: at(0), stops: stops)

        #expect(plan.stops[0].arrival == at(5))
        #expect(plan.stops[0].departure == at(15))
        #expect(plan.stops[1].leaveBy == at(15))
        #expect(plan.stops[1].arrival == at(23))
        #expect(plan.finish == at(53))
        #expect(plan.warnings.isEmpty)
    }

    @Test func leavesJustInTimeForFixedCommitment() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: ["Home>School": 15]))
        let pickup = PlanStop(title: "Kids pickup", place: school, duration: 10 * 60, fixedStart: at(180))
        let plan = scheduler.timeline(from: home, startingAt: at(0), stops: [pickup])

        #expect(plan.stops[0].leaveBy == at(165))
        #expect(plan.stops[0].arrival == at(180))
        #expect(plan.warnings.isEmpty)
    }

    @Test func warnsWhenManualOrderMakesUserLate() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: [:]))
        let groceries = PlanStop(title: "Groceries", place: store, duration: 60 * 60)
        let pickup = PlanStop(title: "Kids pickup", place: school, duration: 10 * 60, fixedStart: at(30))
        let plan = scheduler.timeline(from: home, startingAt: at(0), stops: [groceries, pickup])

        #expect(plan.warnings == [.lateForFixed(stopID: pickup.id, by: 50 * 60)])
    }

    @Test func warnsAboutClosingTimes() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: [:]))
        let closed = PlanStop(title: "Closed", place: cvs, duration: 10 * 60,
                              openHours: TimeRange(start: at(-120), end: at(5)))
        let closing = PlanStop(title: "Closing", place: store, duration: 30 * 60,
                               openHours: TimeRange(start: at(-120), end: at(40)))
        let plan = scheduler.timeline(from: home, startingAt: at(0), stops: [closed, closing])

        #expect(plan.warnings == [.closedOnArrival(stopID: closed.id), .closesBeforeDone(stopID: closing.id)])
    }

    @Test func optimiserProtectsFixedCommitment() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: [:]))
        let groceries = PlanStop(title: "Groceries", place: store, duration: 60 * 60)
        let pickup = PlanStop(title: "Kids pickup", place: school, duration: 10 * 60, fixedStart: at(30))
        let plan = scheduler.optimised(from: home, startingAt: at(0), stops: [groceries, pickup])

        #expect(plan.stops.map(\.stop.title) == ["Kids pickup", "Groceries"])
        #expect(plan.warnings.isEmpty)
    }

    @Test func optimiserKeepsLockedStopsInPlace() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: ["Home>CVS": 1, "Home>Store": 30]))
        let groceries = PlanStop(title: "Groceries", place: store, duration: 10 * 60, isLocked: true)
        let meds = PlanStop(title: "Pick up meds", place: cvs, duration: 10 * 60)
        let plan = scheduler.optimised(from: home, startingAt: at(0), stops: [groceries, meds])

        #expect(plan.stops.map(\.stop.title) == ["Groceries", "Pick up meds"])
    }

    @Test func optimiserPicksShorterOrder() {
        let scheduler = PlanScheduler(travel: TableTravel(minutes: [
            "Home>Store": 30, "Store>CVS": 30, "Home>CVS": 5, "CVS>Store": 5
        ]))
        let groceries = PlanStop(title: "Groceries", place: store, duration: 10 * 60)
        let meds = PlanStop(title: "Pick up meds", place: cvs, duration: 10 * 60)
        let plan = scheduler.optimised(from: home, startingAt: at(0), stops: [groceries, meds])

        #expect(plan.stops.map(\.stop.title) == ["Pick up meds", "Groceries"])
    }

    @Test func permutationsCoversEveryOrder() {
        let all = permutations(of: [1, 2, 3, 4])
        #expect(all.count == 24)
        #expect(Set(all.map { $0.map(String.init).joined() }).count == 24)
    }
}
