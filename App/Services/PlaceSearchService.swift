import Foundation
import MapKit
import ErrandKit

/// Finds places by name, address or category.
protocol PlaceSearchService: Sendable {
    func search(_ query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceRef]
}

/// The search the app uses: Google through the backend when it is set up, otherwise MapKit.
func preferredPlaceSearch() -> any PlaceSearchService {
    if let backend = BackendClient.shared { GooglePlaceSearch(backend: backend) } else { MapKitPlaceSearch() }
}

/// Google Places search through the backend. Results carry Google place IDs,
/// which the app uses for opening hours and the Google Maps handoff.
struct GooglePlaceSearch: PlaceSearchService {
    let backend: BackendClient

    func search(_ query: String, near center: CLLocationCoordinate2D?) async throws -> [PlaceRef] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return try await backend.searchPlaces(trimmed, near: center.map { ($0.latitude, $0.longitude) })
    }
}

/// Fallback using MapKit search, for when the backend isn't configured.
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
                longitude: coordinate.longitude,
                address: item.address?.shortAddress ?? item.address?.fullAddress ?? ""
            )
        }
    }
}
