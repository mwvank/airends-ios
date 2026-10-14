import SwiftUI
import SwiftData
import ErrandKit

/// Adds an errand by typing and searching for a place, without the microphone.
struct AddErrandView: View {
    let nextSortIndex: Int
    var search: any PlaceSearchService = preferredPlaceSearch()

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location
    @Query(sort: \SavedPlace.useCount, order: .reverse) private var savedPlaces: [SavedPlace]

    @State private var title = ""
    @State private var placeQuery = ""
    /// The search that found the selected place, for the dropdown of other choices.
    @State private var lastQuery = ""
    @State private var results: [PlaceRef] = []
    @State private var selectedPlace: PlaceRef?
    @State private var addToMyPlaces = false
    @State private var nickname = ""
    @State private var durationMinutes = 15
    @State private var fixedTime: ClockTime?
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("e.g. Pick up prescription", text: $title)
                }

                Section("Where") {
                    if let selectedPlace {
                        ErrandPlaceRow(
                            place: selectedPlace,
                            query: lastQuery,
                            search: search,
                            addToMyPlaces: $addToMyPlaces,
                            nickname: $nickname,
                            onChoose: { choose($0) },
                            onSearch: { self.selectedPlace = nil }
                        )
                    } else {
                        TextField("Search places, addresses or categories", text: $placeQuery)
                            .textInputAutocapitalization(.never)
                        ForEach(results, id: \.self) { place in
                            Button { choose(place) } label: {
                                PlaceLabel(name: place.name, address: place.address)
                            }
                        }
                        if placeQuery.isEmpty && !savedPlaces.isEmpty {
                            ForEach(savedPlaces.prefix(5)) { saved in
                                Button {
                                    choose(saved.place)
                                } label: {
                                    PlaceLabel(name: saved.nickname ?? saved.name, address: saved.address, systemImage: "star.fill")
                                }
                            }
                        }
                    }
                }

                Section("When") {
                    DurationStepper(minutes: $durationMinutes)
                    FixedTimeRow(time: $fixedTime)
                }

                Section("Notes") {
                    TextField("Shopping list, order number…", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add errand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedPlace == nil)
                }
            }
            .task(id: placeQuery) {
                // Debounce typing before searching.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = (try? await search.search(placeQuery, near: location.current?.coordinate)) ?? []
            }
        }
    }

    private func isSaved(_ place: PlaceRef) -> Bool {
        SavedPlace.existing(for: place, in: context) != nil
    }

    private func choose(_ place: PlaceRef) {
        selectedPlace = place
        if !placeQuery.isEmpty { lastQuery = placeQuery }
        placeQuery = ""
        if fixedTime == nil { fixedTime = SavedPlace.fixedTime(for: place, in: context) }
        results = []
    }

    private func save() {
        guard let place = selectedPlace else { return }
        let errand = Errand(
            title: title.trimmingCharacters(in: .whitespaces),
            place: place,
            durationMinutes: durationMinutes,
            fixedStart: fixedTime?.date(on: .now),
            notes: notes
        )
        errand.sortIndex = nextSortIndex
        context.insert(errand)
        if addToMyPlaces && !isSaved(place) {
            SavedPlace.addToMyPlaces(place, nickname: nickname, in: context)
        } else {
            SavedPlace.recordUse(of: place, in: context)
        }
        dismiss()
    }
}
