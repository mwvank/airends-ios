import Foundation
import SwiftData
import ErrandKit

/// An errand the user wants to do. Stored with SwiftData and synced
/// through the user's iCloud, so every property has a default (a CloudKit requirement).
@Model
final class Errand {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var placeName: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var googlePlaceID: String?
    var durationMinutes: Int = 15
    /// Set for commitments at an exact time, such as school pickup.
    var fixedStart: Date?
    /// Position in the user's route; changed by drag and drop.
    var sortIndex: Int = 0
    var isLocked: Bool = false
    var isDone: Bool = false
    /// The day this errand is planned for (start of day).
    var day: Date = Calendar.current.startOfDay(for: .now)
    var createdAt: Date = Date.now

    init(title: String, place: PlaceRef, durationMinutes: Int, fixedStart: Date? = nil, notes: String = "", day: Date = .now) {
        self.title = title
        self.placeName = place.name
        self.latitude = place.latitude
        self.longitude = place.longitude
        self.googlePlaceID = place.googlePlaceID
        self.durationMinutes = durationMinutes
        self.fixedStart = fixedStart
        self.notes = notes
        self.day = Calendar.current.startOfDay(for: day)
    }

    var place: PlaceRef {
        PlaceRef(name: placeName, latitude: latitude, longitude: longitude, googlePlaceID: googlePlaceID)
    }

    var planStop: PlanStop {
        PlanStop(
            id: id,
            title: title,
            place: place,
            duration: TimeInterval(durationMinutes * 60),
            fixedStart: fixedStart,
            isLocked: isLocked
        )
    }
}
