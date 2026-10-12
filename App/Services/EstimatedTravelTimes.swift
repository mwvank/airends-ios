import Foundation
import CoreLocation
import ErrandKit

/// Rough travel times from straight-line distance, used until the backend
/// provides traffic-aware times from the Google Routes API (milestone 3).
struct EstimatedTravelTimes: TravelTimes {
    /// Average city driving speed, in metres per second (about 25 mph).
    var averageSpeed: Double = 11
    /// Real roads are longer than a straight line.
    var detourFactor: Double = 1.4

    func travelTime(from origin: PlaceRef, to destination: PlaceRef) -> TimeInterval {
        let a = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let b = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let seconds = a.distance(from: b) * detourFactor / averageSpeed
        // Round up to whole minutes, with a minimum of a few minutes for parking.
        return max(3 * 60, (seconds / 60).rounded(.up) * 60)
    }
}

/// Traffic-aware driving times from Google, fetched once for all of today's places.
/// Any pair Google didn't return falls back to the estimate.
struct GoogleTravelTimes: TravelTimes {
    private let index: [String: Int]
    private let seconds: [[Double?]]
    private let fallback = EstimatedTravelTimes()

    init(points: [PlaceRef], seconds: [[Double?]]) {
        var index: [String: Int] = [:]
        for (position, point) in points.enumerated() { index[Self.key(point)] = position }
        self.index = index
        self.seconds = seconds
    }

    func travelTime(from origin: PlaceRef, to destination: PlaceRef) -> TimeInterval {
        if let from = index[Self.key(origin)], let to = index[Self.key(destination)],
           from < seconds.count, to < seconds[from].count, let time = seconds[from][to] {
            // Round up to whole minutes, plus a couple of minutes to park.
            return (time / 60).rounded(.up) * 60 + 2 * 60
        }
        return fallback.travelTime(from: origin, to: destination)
    }

    /// Places within about 10 m count as the same point.
    static func key(_ place: PlaceRef) -> String {
        String(format: "%.4f,%.4f", place.latitude, place.longitude)
    }
}
