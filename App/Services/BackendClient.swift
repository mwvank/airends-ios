import Foundation
import ErrandKit

/// Talks to the Airends backend, which calls Google Maps Platform on the app's behalf
/// so the paid API key never ships in the app.
///
/// The backend address comes from `BACKEND_HOST` in Config/Shared.xcconfig.
/// When it is empty, `shared` is nil and the app falls back to MapKit search
/// and estimated travel times.
struct BackendClient: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    static let shared: BackendClient? = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "AirendsBackendHost") as? String,
              !host.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: "https://\(host)")
        else { return nil }
        return BackendClient(baseURL: url)
    }()

    enum Failure: Error {
        case status(Int)
    }

    // MARK: Places

    private struct PlacesResponse: Decodable {
        struct Place: Decodable {
            let id: String
            let name: String
            let address: String
            let latitude: Double
            let longitude: Double
        }
        let places: [Place]
    }

    func searchPlaces(_ query: String, near: (latitude: Double, longitude: Double)?) async throws -> [PlaceRef] {
        var body: [String: Any] = ["query": query]
        if let near {
            body["latitude"] = near.latitude
            body["longitude"] = near.longitude
        }
        let response: PlacesResponse = try await post("places", body)
        return response.places.map {
            PlaceRef(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, googlePlaceID: $0.id)
        }
    }

    // MARK: Opening hours

    private struct HoursResponse: Decodable {
        struct Range: Decodable {
            let open: String
            let close: String
        }
        let hours: [String: [Range]]
    }

    /// Opening hours on `day` for each place, keyed by Google place ID.
    /// A place with no entry is closed that day, or Google has no hours for it.
    func openingHours(placeIDs: [String], on day: Date) async throws -> [String: [TimeRange]] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        let date = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        var result: [String: [TimeRange]] = [:]
        // The backend accepts up to 10 places per request.
        for start in stride(from: 0, to: placeIDs.count, by: 10) {
            let batch = Array(placeIDs[start..<min(start + 10, placeIDs.count)])
            let response: HoursResponse = try await post("hours", ["placeIds": batch, "date": date])
            for (id, ranges) in response.hours {
                result[id] = ranges.compactMap { range in
                    guard let open = Self.parseDate(range.open), let close = Self.parseDate(range.close) else { return nil }
                    return TimeRange(start: open, end: close)
                }
            }
        }
        return result
    }

    // MARK: Travel times

    private struct TravelTimesResponse: Decodable {
        let seconds: [[Double?]]
    }

    /// The most points one travel time request can take.
    static let maxMatrixPoints = 10

    /// Traffic-aware driving times between every pair of `points`, in seconds; nil where there is no route.
    func travelTimes(between points: [PlaceRef], departure: Date) async throws -> [[Double?]] {
        let body: [String: Any] = [
            "points": points.map { ["latitude": $0.latitude, "longitude": $0.longitude] },
            "departureTime": ISO8601DateFormatter().string(from: departure),
        ]
        let response: TravelTimesResponse = try await post("travelTimes", body)
        return response.seconds
    }

    // MARK: Plumbing

    private func post<Response: Decodable>(_ path: String, _ body: [String: Any]) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Failure.status(status) }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
