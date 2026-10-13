import Foundation
import SwiftData
import ErrandKit

/// A place the user uses often, optionally with a nickname such as "the store".
/// Saved automatically as errands are added, so future errands are one tap away.
@Model
final class SavedPlace {
    var name: String = ""
    var nickname: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var googlePlaceID: String?
    var useCount: Int = 0
    var lastUsed: Date = Date.now

    init(place: PlaceRef) {
        self.name = place.name
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.googlePlaceID = place.googlePlaceID
    }

    /// The nickname as editable text; empty clears it.
    var nicknameText: String {
        get { nickname ?? "" }
        set { nickname = newValue.isEmpty ? nil : newValue.lowercased() }
    }

    var place: PlaceRef {
        PlaceRef(name: name, latitude: latitude, longitude: longitude, googlePlaceID: googlePlaceID)
    }

    /// Records a use of `place`, creating the saved place the first time.
    /// A `nickname` such as "the store" is remembered if the place doesn't have one yet.
    static func recordUse(of place: PlaceRef, nickname: String? = nil, in context: ModelContext) {
        let saved = save(place, in: context)
        saved.useCount += 1
        saved.lastUsed = .now
        if saved.nickname == nil, let nickname { saved.nickname = nickname.lowercased() }
    }

    /// The saved place for `place`, created if it isn't saved yet. A place matches by its
    /// Google place ID, or else by position, so renaming a saved place doesn't duplicate it.
    @discardableResult
    static func save(_ place: PlaceRef, in context: ModelContext) -> SavedPlace {
        let all = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
        let existing = all.first { saved in
            if let id = place.googlePlaceID, saved.googlePlaceID == id { return true }
            return abs(saved.latitude - place.latitude) < 0.0001 && abs(saved.longitude - place.longitude) < 0.0001
        }
        if let existing { return existing }
        let saved = SavedPlace(place: place)
        context.insert(saved)
        return saved
    }
}
