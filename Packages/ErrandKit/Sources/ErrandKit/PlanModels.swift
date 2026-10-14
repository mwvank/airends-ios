import Foundation

/// A place a stop happens at. `googlePlaceID` is the stable identifier used
/// for opening hours, routing and the Google Maps handoff.
public struct PlaceRef: Hashable, Codable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var googlePlaceID: String?
    /// Street address for display, such as "123 Main St, Springfield, NJ". Empty if unknown.
    public var address: String

    public init(name: String, latitude: Double, longitude: Double, googlePlaceID: String? = nil, address: String = "") {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.googlePlaceID = googlePlaceID
    }
}

/// A span of time on a given day, such as a store's opening hours.
public struct TimeRange: Hashable, Codable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool { date >= start && date <= end }
}

/// One stop in a day plan, independent of how it is stored.
public struct PlanStop: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var place: PlaceRef
    /// Expected time spent at the stop.
    public var duration: TimeInterval
    /// A commitment that must start at an exact time, such as school pickup.
    public var fixedStart: Date?
    /// When the place is open on the plan's day. `nil` means unknown or always open.
    public var openHours: TimeRange?
    /// Locked stops keep their position when the rest of the plan is re-optimised.
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        place: PlaceRef,
        duration: TimeInterval,
        fixedStart: Date? = nil,
        openHours: TimeRange? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.place = place
        self.duration = duration
        self.fixedStart = fixedStart
        self.openHours = openHours
        self.isLocked = isLocked
    }
}

/// A problem with a plan that the user should see, for example after
/// dragging a stop into a new position.
public enum PlanWarning: Hashable, Sendable {
    /// Arrives after a fixed commitment's start time.
    case lateForFixed(stopID: UUID, by: TimeInterval)
    /// Arrives after the place has closed.
    case closedOnArrival(stopID: UUID)
    /// The place closes before the errand would be finished.
    case closesBeforeDone(stopID: UUID)
}

/// The computed timing for one stop.
public struct ScheduledStop: Identifiable, Hashable, Sendable {
    public var stop: PlanStop
    /// When to leave the previous location to get here.
    public var leaveBy: Date
    public var travelTime: TimeInterval
    public var arrival: Date
    public var departure: Date

    public var id: UUID { stop.id }
}

/// A fully timed plan with its warnings.
public struct DayPlan: Hashable, Sendable {
    public var stops: [ScheduledStop]
    public var warnings: [PlanWarning]

    public var finish: Date? { stops.last?.departure }
}
