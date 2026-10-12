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
