import SwiftUI
import SwiftData
import ErrandKit

/// Lets the user search for a place or pick one of their saved places.
struct PlacePickerView: View {
    var initialQuery: String = ""
    var search: any PlaceSearchService = preferredPlaceSearch()
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
                                PlaceLabel(name: saved.nickname ?? saved.name, address: saved.address, systemImage: "star.fill")
                            }
                        }
                    }
                }
                Section {
                    ForEach(results, id: \.self) { place in
                        Button { pick(place) } label: {
                            PlaceLabel(name: place.name, address: place.address)
                        }
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

/// A place's name with its address underneath, used wherever places are listed.
struct PlaceLabel: View {
    let name: String
    let address: String
    var systemImage = "mappin.circle.fill"

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).foregroundStyle(.primary)
                if !address.isEmpty {
                    Text(Self.shortened(address))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }

    /// Drops the country from US addresses, which Google includes.
    static func shortened(_ address: String) -> String {
        address.hasSuffix(", USA") ? String(address.dropLast(5)) : address
    }
}
