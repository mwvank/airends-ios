import Foundation
import Testing
@testable import ErrandKit

@Suite struct NavigationHandoffTests {
    func place(_ i: Int, id: String? = nil) -> PlaceRef {
        PlaceRef(name: "Stop \(i)", latitude: 40, longitude: Double(i), googlePlaceID: id)
    }

    func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func googleURLListsStopsInOrder() throws {
        let url = try #require(NavigationHandoff.googleMapsURL(stops: [place(1, id: "a"), place(2, id: "b"), place(3, id: "c")]))
        let q = query(url)

        #expect(url.absoluteString.hasPrefix("https://www.google.com/maps/dir/?api=1"))
        #expect(q["destination"] == "40.0,3.0")
        #expect(q["destination_place_id"] == "c")
        #expect(q["waypoints"] == "40.0,1.0|40.0,2.0")
        #expect(q["waypoint_place_ids"] == "a|b")
        #expect(q["origin"] == nil) // starts from current location
    }

    @Test func googleURLOmitsPartialPlaceIDs() throws {
        let url = try #require(NavigationHandoff.googleMapsURL(stops: [place(1, id: "a"), place(2), place(3)]))
        #expect(query(url)["waypoint_place_ids"] == nil)
    }

    @Test func googleURLRejectsTooManyStops() {
        #expect(NavigationHandoff.googleMapsURL(stops: (1...11).map { place($0) }) == nil)
        #expect(NavigationHandoff.googleMapsURL(stops: []) == nil)
    }

    @Test func longPlansAreSplitIntoBatches() {
        let batches = NavigationHandoff.googleBatches((1...23).map { place($0) })
        #expect(batches.map(\.count) == [10, 10, 3])
    }

    @Test func appleURLTargetsSingleStop() throws {
        let url = try #require(NavigationHandoff.appleMapsURL(to: place(1)))
        #expect(query(url)["daddr"] == "40.0,1.0")
    }
}

@Suite struct EntitlementTests {
    @Test func launchPolicyOnlyRemovesAdsForPro() {
        let policy = EntitlementPolicy.launch
        #expect(!policy.isUnlocked(.adFree, for: .free))
        #expect(policy.isUnlocked(.adFree, for: .pro))
        #expect(policy.isUnlocked(.widgets, for: .free))
    }

    @Test func freeReplansAreLimited() {
        let policy = EntitlementPolicy.launch
        #expect(policy.canReplan(tier: .free, replansToday: policy.freeDailyReplans - 1))
        #expect(!policy.canReplan(tier: .free, replansToday: policy.freeDailyReplans))
        #expect(policy.canReplan(tier: .pro, replansToday: 1_000))
    }

    @Test func policyRoundTripsThroughRemoteConfigJSON() throws {
        let data = try JSONEncoder().encode(EntitlementPolicy.launch)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"pro\""))
        #expect(try JSONDecoder().decode(EntitlementPolicy.self, from: data) == .launch)
    }
}
