import Foundation
import MapKit
import ErrandKit

/// Finds places by name, address or category.
protocol PlaceSearchService: Sendable {
    func search(_ query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceRef]
}

/// Development stand-in using MapKit search so the app works before the backend exists.
/// Milestone 3 replaces this with Google Places Autocomplete through the backend,
/// which returns the Google place IDs used for hours, routing and the Google Maps handoff.
struct MapKitPlaceSearch: PlaceSearchService {
    func search(_ query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceRef] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let center {
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(10).map { item in
            let coordinate = item.location.coordinate
            return PlaceRef(
                name: item.name ?? trimmed,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }
}
