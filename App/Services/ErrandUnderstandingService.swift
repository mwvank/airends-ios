import Foundation
import FoundationModels
import ErrandKit

/// Turns "stop at CVS for my meds and get the kids at 3" into structured errands.
protocol ErrandUnderstandingService: Sendable {
    func understand(_ text: String) async -> [ParsedErrand]
}

/// Uses Apple's on-device language model when available, which is private,
/// free and works offline. Falls back to the rule-based parser on iPhones
/// without Apple Intelligence or if the model fails. A cloud model through the
/// backend can be added as a middle tier later.
struct OnDeviceErrandUnderstanding: ErrandUnderstandingService {
    func understand(_ text: String) async -> [ParsedErrand] {
        guard case .available = SystemLanguageModel.default.availability else {
            return HeuristicErrandParser.parse(text)
        }
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: text, generating: GeneratedErrandList.self)
            let errands = response.content.errands.map(\.parsed)
            return errands.isEmpty ? HeuristicErrandParser.parse(text) : errands
        } catch {
            return HeuristicErrandParser.parse(text)
        }
    }

    static let instructions = """
        You turn what a busy person says about their day into a list of errands.
        Create one errand per separate stop. Combine phrases that describe the same stop,
        for example "go to the store and do the grocery shopping" is one errand.
        Keep place names exactly as the user said them, including words like "the" or "my".
        Only give a fixed time when the user said one.
        """
}

@Generable
struct GeneratedErrandList {
    @Guide(description: "Each separate errand the user mentioned, in the order mentioned")
    var errands: [GeneratedErrand]
}

@Generable
struct GeneratedErrand {
    @Guide(description: "Short action title, for example 'Pick up prescription'")
    var title: String

    @Guide(description: "The specific place as the user said it, for example 'CVS', 'the store' or 'school'. Empty if the user named no place.")
    var place: String

    @Guide(description: "If no specific place was named, the kind of place to search for, for example 'pharmacy' or 'grocery store'. Otherwise empty.")
    var placeCategory: String

    @Guide(description: "Fixed start time in 24-hour HH:mm if the user gave one, for example '15:00'. Otherwise empty.")
    var fixedTime: String

    @Guide(description: "Typical minutes spent at the place, between 5 and 240")
    var minutes: Int

    var parsed: ParsedErrand {
        let query = [place, placeCategory]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return ParsedErrand(
            title: title,
            placeQuery: query,
            fixedTime: ClockTime(hhmm: fixedTime),
            durationMinutes: min(max(minutes, 5), 240)
        )
    }
}
