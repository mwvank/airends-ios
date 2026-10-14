import Foundation
import SwiftData
import ErrandKit

/// A place the user uses often, optionally with a nickname such as "the store".
/// Added when the user stars a place, so future errands are one tap away.
@Model
final class SavedPlace {
    var name: String = ""
    var nickname: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var googlePlaceID: String?
    var address: String = ""
    var useCount: Int = 0
    var lastUsed: Date = Date.now

    init(place: PlaceRef) {
        self.name = place.name
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.googlePlaceID = place.googlePlaceID
        self.address = place.address
    }

    /// The nickname as editable text; empty clears it.
    var nicknameText: String {
        get { nickname ?? "" }
        set { nickname = newValue.isEmpty ? nil : newValue.lowercased() }
    }

    var place: PlaceRef {
        PlaceRef(name: name, latitude: latitude, longitude: longitude, googlePlaceID: googlePlaceID, address: address)
    }

    /// Counts a use of `place` if it's already in My places. Places are only
    /// ever added when the user asks, with `addToMyPlaces`.
    static func recordUse(of place: PlaceRef, in context: ModelContext) {
        guard let saved = existing(for: place, in: context) else { return }
        saved.useCount += 1
        saved.lastUsed = .now
    }

    /// Adds `place` to My places (or updates it), with an optional nickname such as "the store".
    static func addToMyPlaces(_ place: PlaceRef, nickname: String?, in context: ModelContext) {
        let saved = save(place, in: context)
        saved.useCount += 1
        saved.lastUsed = .now
        if let nickname = nickname?.trimmingCharacters(in: .whitespaces), !nickname.isEmpty {
            saved.nickname = nickname.lowercased()
        }
    }

    /// The saved place for `place`, created if it isn't saved yet.
    @discardableResult
    static func save(_ place: PlaceRef, in context: ModelContext) -> SavedPlace {
        if let existing = existing(for: place, in: context) { return existing }
        let saved = SavedPlace(place: place)
        context.insert(saved)
        return saved
    }

    /// The saved place matching `place` by Google place ID, or else by position,
    /// so renaming a saved place doesn't stop it matching.
    static func existing(for place: PlaceRef, in context: ModelContext) -> SavedPlace? {
        let all = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
        return all.first { saved in
            if saved.isDeleted { return false }
            if let id = place.googlePlaceID, saved.googlePlaceID == id { return true }
            return abs(saved.latitude - place.latitude) < 0.0001 && abs(saved.longitude - place.longitude) < 0.0001
        }
    }
}
