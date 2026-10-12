import Foundation

/// Supplies travel times between places. The production implementation
/// pre-fetches a traffic-aware matrix from the Google Routes API (through
/// the backend) for the plan's departure time, so lookups here are synchronous.
public protocol TravelTimes: Sendable {
    func travelTime(from origin: PlaceRef, to destination: PlaceRef) -> TimeInterval
}

/// Times a plan in a given order and finds a good order.
///
/// Timing rules:
/// - Each stop is reached as early as possible after the previous one.
/// - For a fixed commitment, or a place that is not open yet, the user
///   leaves later rather than waiting on arrival.
public struct PlanScheduler: Sendable {
    /// Above this many movable stops, ordering falls back to a greedy search.
    public static let exhaustiveLimit = 8

    public var travel: any TravelTimes

    public init(travel: any TravelTimes) {
        self.travel = travel
    }

    /// Times the stops in exactly the order given, as after a manual drag and drop.
    public func timeline(from origin: PlaceRef, startingAt start: Date, stops: [PlanStop]) -> DayPlan {
        var scheduled: [ScheduledStop] = []
        var warnings: [PlanWarning] = []
        var location = origin
        var readyAt = start

        for stop in stops {
            let travelTime = travel.travelTime(from: location, to: stop.place)
            var leaveBy = readyAt
            if let fixed = stop.fixedStart {
                leaveBy = max(leaveBy, fixed.addingTimeInterval(-travelTime))
            }
            if let open = stop.openHours {
                leaveBy = max(leaveBy, open.start.addingTimeInterval(-travelTime))
            }
            let arrival = leaveBy.addingTimeInterval(travelTime)
            let departure = arrival.addingTimeInterval(stop.duration)

            if let fixed = stop.fixedStart, arrival > fixed {
                warnings.append(.lateForFixed(stopID: stop.id, by: arrival.timeIntervalSince(fixed)))
            }
            if let open = stop.openHours {
                if arrival > open.end {
                    warnings.append(.closedOnArrival(stopID: stop.id))
                } else if departure > open.end {
                    warnings.append(.closesBeforeDone(stopID: stop.id))
                }
            }

            scheduled.append(ScheduledStop(
                stop: stop,
                leaveBy: leaveBy,
                travelTime: travelTime,
                arrival: arrival,
                departure: departure
            ))
            location = stop.place
            readyAt = departure
        }
        return DayPlan(stops: scheduled, warnings: warnings)
    }

    /// Reorders the stops that are not locked to finish as early as possible
    /// while avoiding warnings. Locked stops keep their positions.
    public func optimised(from origin: PlaceRef, startingAt start: Date, stops: [PlanStop]) -> DayPlan {
        let movable = stops.filter { !$0.isLocked }
        let freeSlots = stops.indices.filter { !stops[$0].isLocked }

        func arrange(_ order: [PlanStop]) -> [PlanStop] {
            var result = stops
            for (slot, stop) in zip(freeSlots, order) { result[slot] = stop }
            return result
        }

        var best = timeline(from: origin, startingAt: start, stops: stops)
        var bestScore = score(best, start: start)

        let candidates: [[PlanStop]] = movable.count <= Self.exhaustiveLimit
            ? permutations(of: movable)
            : [greedyOrder(from: origin, stops: movable)]

        for order in candidates {
            let plan = timeline(from: origin, startingAt: start, stops: arrange(order))
            let planScore = score(plan, start: start)
            if planScore < bestScore {
                best = plan
                bestScore = planScore
            }
        }
        return best
    }

    /// Lower is better: total time in seconds plus heavy penalties for warnings.
    func score(_ plan: DayPlan, start: Date) -> Double {
        var total = (plan.finish ?? start).timeIntervalSince(start)
        for warning in plan.warnings {
            switch warning {
            case .lateForFixed(_, let by): total += 100_000 + by * 100
            case .closedOnArrival: total += 1_000_000
            case .closesBeforeDone: total += 50_000
            }
        }
        return total
    }

    func greedyOrder(from origin: PlaceRef, stops: [PlanStop]) -> [PlanStop] {
        var remaining = stops
        var location = origin
        var order: [PlanStop] = []
        while !remaining.isEmpty {
            let nextIndex = remaining.indices.min { lhs, rhs in
                travel.travelTime(from: location, to: remaining[lhs].place)
                    < travel.travelTime(from: location, to: remaining[rhs].place)
            }!
            let next = remaining.remove(at: nextIndex)
            order.append(next)
            location = next.place
        }
        return order
    }
}

/// All orderings of `items` (Heap's algorithm).
func permutations<T>(of items: [T]) -> [[T]] {
    var result: [[T]] = []
    var array = items
    func generate(_ n: Int) {
        if n <= 1 {
            result.append(array)
            return
        }
        for i in 0..<n {
            generate(n - 1)
            array.swapAt(n % 2 == 0 ? i : 0, n - 1)
        }
    }
    generate(array.count)
    return result
}
