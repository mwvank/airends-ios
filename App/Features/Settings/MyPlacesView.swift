import SwiftUI
import SwiftData
import MapKit
import ErrandKit

/// Saved places and their nicknames, so "the store" or "the gym" means the user's own place.
/// Places are saved automatically as errands are added, and can be added, edited or removed here.
struct MyPlacesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPlace.useCount, order: .reverse) private var places: [SavedPlace]
    @State private var addingPlace = false

    var body: some View {
        List {
            if places.isEmpty {
                ContentUnavailableView("No saved places yet", systemImage: "star",
                                       description: Text("Places you use are saved here automatically. Tap + to add one now."))
            }
            ForEach(places) { place in
                NavigationLink {
                    EditPlaceView(place: place)
                } label: {
                    PlaceRow(place: place)
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(places[index]) }
            }
        }
        .navigationTitle("My places")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add place", systemImage: "plus") { addingPlace = true }
            }
            if !places.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .sheet(isPresented: $addingPlace) {
            PlacePickerView { place in
                SavedPlace.save(place, in: context)
            }
        }
    }
}

private struct PlaceRow: View {
    let place: SavedPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name).font(.headline)
            if let nickname = place.nickname {
                Text("“\(nickname)”").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Used \(place.useCount) \(place.useCount == 1 ? "time" : "times")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Edits one saved place: its name, nickname and location.
private struct EditPlaceView: View {
    @Bindable var place: SavedPlace
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var changingLocation = false
    @State private var confirmingDelete = false
    @State private var removeOnClose = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $place.name)
            }
            Section {
                TextField("e.g. the store", text: $place.nicknameText)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Nickname")
            } footer: {
                Text("Say the nickname when planning by voice, like “stop at the store”.")
            }
            Section("Location") {
                Map(initialPosition: .region(region), interactionModes: []) {
                    Marker(place.name, coordinate: coordinate)
                }
                .frame(height: 180)
                .listRowInsets(EdgeInsets())
                .id("\(place.latitude),\(place.longitude)")
                Button("Change location", systemImage: "mappin.and.ellipse") { changingLocation = true }
            }
            Section {
                Button("Remove from My places", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(place.nickname ?? place.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $changingLocation) {
            PlacePickerView(initialQuery: place.name) { newPlace in
                place.latitude = newPlace.latitude
                place.longitude = newPlace.longitude
                place.googlePlaceID = newPlace.googlePlaceID
            }
        }
        .onDisappear {
            if removeOnClose { context.delete(place) }
        }
        .confirmationDialog("Remove \(place.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                // Delete after the screen closes, so it never shows a deleted place.
                removeOnClose = true
                dismiss()
            }
        } message: {
            Text("Errands already planned there are kept.")
        }
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
    }
}
