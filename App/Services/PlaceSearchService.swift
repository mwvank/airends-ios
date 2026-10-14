import Foundation
import MapKit
import SwiftData
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

/// Looks up street addresses for places saved before addresses were stored,
/// so every errand and saved place shows where it actually is.
@MainActor
enum AddressLookup {
    /// The street address at a coordinate, from Apple's reverse geocoder.
    static func address(latitude: Double, longitude: Double) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: latitude, longitude: longitude)),
              let item = try? await request.mapItems.first,
              let text = item.address?.shortAddress ?? item.address?.fullAddress,
              !text.isEmpty
        else { return nil }
        return text
    }

    /// Fills in the address of every errand and saved place that has none.
    /// Apple limits how fast addresses can be looked up, so each run handles a batch.
    static func fillMissing(in context: ModelContext) async {
        let errands = (try? context.fetch(FetchDescriptor<Errand>(predicate: #Predicate { $0.placeAddress == "" }))) ?? []
        let places = (try? context.fetch(FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.address == "" }))) ?? []
        var found: [String: String] = [:]
        var lookups = 0
        func lookUp(_ latitude: Double, _ longitude: Double) async -> String? {
            let key = "\(latitude),\(longitude)"
            if let known = found[key] { return known }
            guard lookups < 40 else { return nil }
            lookups += 1
            let result = await Self.address(latitude: latitude, longitude: longitude)
            if let result { found[key] = result }
            return result
        }
        for place in places {
            if let address = await lookUp(place.latitude, place.longitude), !place.isDeleted { place.address = address }
        }
        for errand in errands {
            if let address = await lookUp(errand.latitude, errand.longitude), !errand.isDeleted { errand.placeAddress = address }
        }
    }
}
