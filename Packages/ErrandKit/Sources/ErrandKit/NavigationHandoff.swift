import Foundation

/// The app the user navigates with once a plan is confirmed.
public enum NavigationApp: String, CaseIterable, Codable, Sendable {
    case googleMaps
    case appleMaps
}

/// Builds links that open a planned route in Google Maps or Apple Maps.
public enum NavigationHandoff {
    /// Google Maps accepts at most 9 waypoints between origin and destination.
    public static let googleMaxWaypoints = 9

    /// Splits stops into legs Google Maps can open in one go
    /// (up to 9 waypoints plus a destination).
    public static func googleBatches(_ stops: [PlaceRef]) -> [[PlaceRef]] {
        let size = googleMaxWaypoints + 1
        return stride(from: 0, to: stops.count, by: size).map {
            Array(stops[$0..<min($0 + size, stops.count)])
        }
    }

    /// A Google Maps URL for one batch of stops, starting from the user's
    /// current location. Opens the Google Maps app when installed, otherwise the browser.
    /// See https://developers.google.com/maps/documentation/urls/get-started
    public static func googleMapsURL(stops: [PlaceRef]) -> URL? {
        guard let destination = stops.last, stops.count <= googleMaxWaypoints + 1 else { return nil }
        let waypoints = stops.dropLast()

        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        var items = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: coordinate(destination)),
            URLQueryItem(name: "travelmode", value: "driving"),
            URLQueryItem(name: "dir_action", value: "navigate")
        ]
        if let placeID = destination.googlePlaceID {
            items.append(URLQueryItem(name: "destination_place_id", value: placeID))
        }
        if !waypoints.isEmpty {
            items.append(URLQueryItem(name: "waypoints", value: waypoints.map(coordinate).joined(separator: "|")))
            // Place IDs must line up with waypoints one to one, so only send them when every stop has one.
            let placeIDs = waypoints.compactMap(\.googlePlaceID)
            if placeIDs.count == waypoints.count {
                items.append(URLQueryItem(name: "waypoint_place_ids", value: placeIDs.joined(separator: "|")))
            }
        }
        components.queryItems = items
        return components.url
    }

    /// An Apple Maps URL with driving directions to a single stop.
    /// Apple Maps links take one destination, so the app hands off the next stop each time.
    public static func appleMapsURL(to stop: PlaceRef) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "daddr", value: coordinate(stop)),
            URLQueryItem(name: "q", value: stop.name),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        return components.url
    }

    static func coordinate(_ place: PlaceRef) -> String {
        "\(place.latitude),\(place.longitude)"
    }
}
