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

    var place: PlaceRef {
        PlaceRef(name: name, latitude: latitude, longitude: longitude, googlePlaceID: googlePlaceID)
    }

    /// Records a use of `place`, creating the saved place the first time.
    static func recordUse(of place: PlaceRef, in context: ModelContext) {
        let name = place.name
        let descriptor = FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.name == name })
        let existing = (try? context.fetch(descriptor))?.first { $0.latitude == place.latitude && $0.longitude == place.longitude }
        let saved = existing ?? SavedPlace(place: place)
        if existing == nil { context.insert(saved) }
        saved.useCount += 1
        saved.lastUsed = .now
    }
}
