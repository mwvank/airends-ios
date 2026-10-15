import Foundation
import ErrandKit

/// Talks to the Errandeer backend, which calls Google Maps Platform on the app's behalf
/// so the paid API key never ships in the app.
///
/// The backend address comes from `BACKEND_HOST` in Config/Shared.xcconfig.
/// When it is empty, `shared` is nil and the app falls back to MapKit search
/// and estimated travel times.
struct BackendClient: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    static let shared: BackendClient? = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "ErrandeerBackendHost") as? String,
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
            /// Only present when the search asked for hours.
            let hours: [Range]?
        }
        let places: [Place]
    }

    /// Searches for places. With `hoursOn`, Google also returns each place's hours
    /// that day, which costs more per search, so only the short "other places" list uses it.
    func searchPlaces(_ query: String, near: (latitude: Double, longitude: Double)?, hoursOn day: Date? = nil) async throws -> [PlaceRef] {
        var body: [String: Any] = ["query": query]
        if let near {
            body["latitude"] = near.latitude
            body["longitude"] = near.longitude
        }
        if let day { body["date"] = Self.dateString(day) }
        let response: PlacesResponse = try await post("places", body)
        if let day {
            var hours: [String: [TimeRange]] = [:]
            for place in response.places {
                if let ranges = place.hours { hours[place.id] = Self.timeRanges(ranges) }
            }
            await HoursCache.shared.store(hours, date: Self.dateString(day))
        }
        return response.places.map {
            PlaceRef(name: $0.name, latitude: $0.latitude, longitude: $0.longitude, googlePlaceID: $0.id, address: $0.address)
        }
    }

    // MARK: Opening hours

    private struct Range: Decodable {
        let open: String
        let close: String
    }

    private struct HoursResponse: Decodable {
        let hours: [String: [Range]]
    }

    private static func dateString(_ day: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func timeRanges(_ ranges: [Range]) -> [TimeRange] {
        ranges.compactMap { range in
            guard let open = parseDate(range.open), let close = parseDate(range.close) else { return nil }
            return TimeRange(start: open, end: close)
        }
    }

    /// Opening hours on `day` for each place, keyed by Google place ID.
    /// A place with an empty list is closed that day, or Google has no hours for it.
    /// Each place's hours are fetched at most once a day per app launch, since
    /// every lookup is a paid Google request.
    func openingHours(placeIDs: [String], on day: Date) async throws -> [String: [TimeRange]] {
        let date = Self.dateString(day)
        var result = await HoursCache.shared.lookup(placeIDs, date: date)
        let missing = placeIDs.filter { result[$0] == nil }
        // The backend accepts up to 10 places per request.
        for start in stride(from: 0, to: missing.count, by: 10) {
            let batch = Array(missing[start..<min(start + 10, missing.count)])
            let response: HoursResponse = try await post("hours", ["placeIds": batch, "date": date])
            var fetched: [String: [TimeRange]] = [:]
            for id in batch {
                fetched[id] = Self.timeRanges(response.hours[id] ?? [])
            }
            await HoursCache.shared.store(fetched, date: date)
            result.merge(fetched) { _, new in new }
        }
        return result
    }

    /// The closing time shown on an errand card, such as "Closes 9:00 PM" or "Closed today".
    /// Nil when it isn't known.
    /// With `lookUpIfMissing` false, only hours already fetched are used, so it never costs a request.
    func closingText(placeID: String, on day: Date = .now, lookUpIfMissing: Bool = true) async -> String? {
        let ranges: [TimeRange]?
        if lookUpIfMissing {
            ranges = try? await openingHours(placeIDs: [placeID], on: day)[placeID]
        } else {
            ranges = await HoursCache.shared.lookup([placeID], date: Self.dateString(day))[placeID]
        }
        guard let ranges else { return nil }
        guard let close = ranges.map(\.end).max() else { return "Closed today" }
        if close.timeIntervalSince(Calendar.current.startOfDay(for: day)) >= 24 * 60 * 60 - 60 { return "Open 24 hours" }
        return "Closes \(close.formatted(date: .omitted, time: .shortened))"
    }

    /// Opening hours already fetched this launch, so the errand card and the
    /// Today plan share one lookup per place per day.
    private actor HoursCache {
        static let shared = HoursCache()
        private var entries: [String: [TimeRange]] = [:]

        func lookup(_ ids: [String], date: String) -> [String: [TimeRange]] {
            var found: [String: [TimeRange]] = [:]
            for id in ids { if let ranges = entries["\(id)|\(date)"] { found[id] = ranges } }
            return found
        }

        func store(_ hours: [String: [TimeRange]], date: String) {
            for (id, ranges) in hours { entries["\(id)|\(date)"] = ranges }
        }
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
