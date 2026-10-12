import Foundation

/// A time of day without a date, such as "3:00 PM".
public struct ClockTime: Hashable, Codable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Parses 24-hour "HH:mm", as produced by the language model.
    public init?(hhmm: String) {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        self.init(hour: parts[0], minute: parts[1])
    }

    public func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

/// One errand understood from what the user said or typed, before its place is resolved.
public struct ParsedErrand: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    /// The place as the user said it ("CVS", "the store"), or a category to search for ("pharmacy").
    public var placeQuery: String?
    public var fixedTime: ClockTime?
    public var durationMinutes: Int

    public init(id: UUID = UUID(), title: String, placeQuery: String?, fixedTime: ClockTime? = nil, durationMinutes: Int) {
        self.id = id
        self.title = title
        self.placeQuery = placeQuery
        self.fixedTime = fixedTime
        self.durationMinutes = durationMinutes
    }
}

/// Common kinds of errand, with a sensible default duration and what to search for
/// when the user didn't name a specific place. Learned durations replace these later.
public enum ErrandCategory: CaseIterable, Sendable {
    case pharmacy, grocery, school, postOffice, bank, gas, dryCleaning

    var keywords: [String] {
        switch self {
        case .pharmacy: ["pharmacy", "cvs", "walgreens", "rite aid", "prescription", "medication", "medicine", "meds"]
        case .grocery: ["grocery", "groceries", "supermarket"]
        case .school: ["school", "kids", "children", "daycare"]
        case .postOffice: ["post office", "usps", "mail", "package", "stamps"]
        case .bank: ["bank", "deposit", "atm"]
        case .gas: ["gas", "fuel", "fill up"]
        case .dryCleaning: ["dry clean", "dry-clean", "cleaners", "laundry"]
        }
    }

    public var defaultMinutes: Int {
        switch self {
        case .pharmacy: 10
        case .grocery: 35
        case .school: 10
        case .postOffice: 15
        case .bank: 10
        case .gas: 10
        case .dryCleaning: 5
        }
    }

    public var searchQuery: String {
        switch self {
        case .pharmacy: "pharmacy"
        case .grocery: "grocery store"
        case .school: "school"
        case .postOffice: "post office"
        case .bank: "bank"
        case .gas: "gas station"
        case .dryCleaning: "dry cleaner"
        }
    }

    public static func detect(in text: String) -> ErrandCategory? {
        let lowered = text.lowercased()
        return allCases.first { category in
            category.keywords.contains { lowered.range(of: "\\b\($0)", options: .regularExpression) != nil }
        }
    }
}

/// A rule-based parser used when the on-device language model isn't available
/// (older iPhones, Apple Intelligence turned off) or fails. It handles everyday
/// phrasing like "stop at CVS to pick up my meds and get the kids at 3".
public enum HeuristicErrandParser {
    static let fillers = [
        "today", "this morning", "this afternoon", "tonight", "first", "after that", "and", "also", "then",
        "i need to", "i have to", "i've got to", "i gotta", "i want to", "i should", "need to", "have to",
        "remind me to", "please"
    ]

    /// Words that start an activity rather than a place, so "go to pick up dry cleaning"
    /// isn't read as a place called "pick up dry cleaning".
    static let verbs = ["pick", "get", "buy", "drop", "grab", "return", "mail", "deposit", "fill", "go", "do", "see", "take"]

    public static func parse(_ text: String) -> [ParsedErrand] {
        let fragments = text
            .replacingOccurrences(of: "\\s*(,|;|\\.(?!\\d)|\\band then\\b|\\bthen\\b|\\band\\b|\\balso\\b)\\s*", with: "|", options: [.regularExpression, .caseInsensitive])
            .split(separator: "|")
            .map { stripFillers(String($0)) }
            .filter { $0.count >= 3 }

        var errands: [(errand: ParsedErrand, hasExplicitPlace: Bool, category: ErrandCategory?)] = []
        for fragment in fragments {
            var remaining = fragment
            let time = extractTime(from: &remaining)
            let (place, purpose) = extractPlace(from: remaining)
            let category = ErrandCategory.detect(in: remaining)
            let title = capitalized(purpose ?? remaining)

            // "Go to the store and go grocery shopping" is one errand: a categorised
            // activity with no place joins the previous fragment that named a place.
            if place == nil, time == nil, let category,
               let last = errands.last, last.hasExplicitPlace, last.category == nil {
                errands[errands.count - 1] = (
                    ParsedErrand(id: last.errand.id, title: title, placeQuery: last.errand.placeQuery,
                                 fixedTime: last.errand.fixedTime, durationMinutes: category.defaultMinutes),
                    true, category
                )
                continue
            }

            errands.append((
                ParsedErrand(title: title, placeQuery: place ?? category?.searchQuery, fixedTime: time,
                             durationMinutes: category?.defaultMinutes ?? 15),
                place != nil, category
            ))
        }
        return errands.map { $0.errand }
    }

    static func stripFillers(_ fragment: String) -> String {
        var text = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            for filler in fillers where text.lowercased().hasPrefix(filler + " ") || text.lowercased() == filler {
                text = String(text.dropFirst(filler.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }
        return text
    }

    /// Finds "at 3", "by 3:30pm", "around 10 am", removes it and returns the time.
    /// Without am/pm, 1–7 o'clock is read as afternoon (errands rarely start at 3 AM).
    static func extractTime(from text: inout String) -> ClockTime? {
        let pattern = "\\s*\\b(?:at|by|around)\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(a\\.?m\\.?|p\\.?m\\.?)?(?=\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]), (0...23).contains(hour)
        else { return nil }

        let minute = Range(match.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
        let meridiem = Range(match.range(at: 3), in: text).map { text[$0].lowercased() }
        if let meridiem {
            if meridiem.hasPrefix("p"), hour < 12 { hour += 12 }
            if meridiem.hasPrefix("a"), hour == 12 { hour = 0 }
        } else if (1...7).contains(hour) {
            hour += 12
        }
        guard minute < 60 else { return nil }

        if let whole = Range(match.range, in: text) { text.removeSubrange(whole) }
        text = text.trimmingCharacters(in: .whitespaces)
        return ClockTime(hour: hour, minute: minute)
    }

    /// Finds "at CVS", "to the store", "from school". Returns the place and,
    /// for "at CVS to pick up my meds", the purpose to use as the title.
    static func extractPlace(from text: String) -> (place: String?, purpose: String?) {
        guard let regex = try? NSRegularExpression(pattern: "\\b(?:at|to|from)\\s+", options: .caseInsensitive) else { return (nil, nil) }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let rest = String(text[range.upperBound...])
            let firstWord = rest.split(separator: " ").first.map { $0.lowercased() } ?? ""
            if firstWord.isEmpty || verbs.contains(firstWord) { continue }

            if let purposeRange = rest.range(of: "\\s+(?:to|for)\\s+", options: [.regularExpression, .caseInsensitive]) {
                let place = String(rest[..<purposeRange.lowerBound])
                let purpose = String(rest[purposeRange.upperBound...])
                return (place, purpose.isEmpty ? nil : purpose)
            }
            return (rest, nil)
        }
        return (nil, nil)
    }

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
