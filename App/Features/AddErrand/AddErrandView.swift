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
    @State private var results: [PlaceRef] = []
    @State private var selectedPlace: PlaceRef?
    @State private var addToMyPlaces = false
    @State private var nickname = ""
    @State private var durationMinutes = 15
    @State private var hasFixedTime = false
    @State private var fixedTime = Date.now
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("e.g. Pick up prescription", text: $title)
                }

                Section("Where") {
                    if let selectedPlace {
                        HStack {
                            Label(selectedPlace.name, systemImage: "mappin.circle.fill")
                            Spacer()
                            Button("Change") { self.selectedPlace = nil }
                        }
                        AddToMyPlacesControl(isOn: $addToMyPlaces, nickname: $nickname,
                                             alreadySaved: isSaved(selectedPlace))
                    } else {
                        TextField("Search places, addresses or categories", text: $placeQuery)
                            .textInputAutocapitalization(.never)
                        ForEach(results, id: \.self) { place in
                            Button(place.name) { choose(place) }
                        }
                        if placeQuery.isEmpty && !savedPlaces.isEmpty {
                            ForEach(savedPlaces.prefix(5)) { saved in
                                Button {
                                    choose(saved.place)
                                } label: {
                                    Label(saved.nickname ?? saved.name, systemImage: "star.fill")
                                }
                            }
                        }
                    }
                }

                Section("When") {
                    Stepper("About \(durationMinutes) min there", value: $durationMinutes, in: 5...240, step: 5)
                    Toggle("Fixed time", isOn: $hasFixedTime)
                    if hasFixedTime {
                        DatePicker("Starts at", selection: $fixedTime, displayedComponents: .hourAndMinute)
                    }
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
        placeQuery = ""
        results = []
    }

    private func save() {
        guard let place = selectedPlace else { return }
        let errand = Errand(
            title: title.trimmingCharacters(in: .whitespaces),
            place: place,
            durationMinutes: durationMinutes,
            fixedStart: hasFixedTime ? fixedTime : nil,
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
