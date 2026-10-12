import Foundation
import Observation

/// Errands dictated through Siri, waiting for the app to show them for review.
@MainActor
@Observable
final class PendingPlanRequest {
    static let shared = PendingPlanRequest()

    struct Request: Identifiable {
        let id = UUID()
        let text: String
    }

    var request: Request?

    func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request = Request(text: trimmed)
    }
}
