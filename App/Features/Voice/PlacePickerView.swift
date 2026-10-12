import SwiftUI
import SwiftData
import ErrandKit

/// Lets the user search for a place or pick one of their saved places.
struct PlacePickerView: View {
    var initialQuery: String = ""
    var search: any PlaceSearchService = MapKitPlaceSearch()
    var onPick: (PlaceRef) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location
    @Query(sort: \SavedPlace.useCount, order: .reverse) private var savedPlaces: [SavedPlace]

    @State private var query = ""
    @State private var results: [PlaceRef] = []

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty, !savedPlaces.isEmpty {
                    Section("My places") {
                        ForEach(savedPlaces) { saved in
                            Button { pick(saved.place) } label: {
                                Label(saved.nickname ?? saved.name, systemImage: "star.fill")
                            }
                        }
                    }
                }
                Section {
                    ForEach(results, id: \.self) { place in
                        Button(place.name) { pick(place) }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search places")
            .navigationTitle("Choose place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if query.isEmpty { query = initialQuery } }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = (try? await search.search(query, near: location.current?.coordinate)) ?? []
            }
        }
    }

    private func pick(_ place: PlaceRef) {
        onPick(place)
        dismiss()
    }
}
