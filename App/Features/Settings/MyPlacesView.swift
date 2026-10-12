import SwiftUI
import SwiftData

/// Saved places and their nicknames, so "the store" or "the gym" means the user's own place.
struct MyPlacesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPlace.useCount, order: .reverse) private var places: [SavedPlace]

    var body: some View {
        List {
            if places.isEmpty {
                ContentUnavailableView("No saved places yet", systemImage: "star",
                                       description: Text("Places you use are saved here automatically."))
            }
            ForEach(places) { place in
                PlaceRow(place: place)
            }
            .onDelete { offsets in
                for index in offsets { context.delete(places[index]) }
            }
        }
        .navigationTitle("My places")
    }
}

private struct PlaceRow: View {
    @Bindable var place: SavedPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name).font(.headline)
            TextField("Nickname, e.g. the store", text: $place.nicknameText)
                .textInputAutocapitalization(.never)
            Text("Used \(place.useCount) \(place.useCount == 1 ? "time" : "times")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
