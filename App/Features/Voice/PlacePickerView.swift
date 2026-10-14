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

/// The place on an errand card. The pin and address on the left drop down other
/// places to choose from; the star on the right adds the place to My places,
/// or, for a place already there, drops down its nickname and a remove button.
struct ErrandPlaceRow: View {
    let place: PlaceRef?
    /// What to search for when the dropdown opens, such as what the user said.
    var query: String = ""
    var search: any PlaceSearchService = preferredPlaceSearch()
    @Binding var addToMyPlaces: Bool
    @Binding var nickname: String
    var onChoose: (PlaceRef) -> Void
    /// Opens a full search for a place not in the dropdown.
    var onSearch: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(LocationService.self) private var location
    @Query(sort: \SavedPlace.useCount, order: .reverse) private var savedPlaces: [SavedPlace]

    @State private var showingChoices = false
    @State private var showingStarOptions = false
    @State private var results: [PlaceRef] = []
    @State private var isSearching = false

    private var saved: SavedPlace? {
        place.flatMap { SavedPlace.existing(for: $0, in: context) }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { showingChoices.toggle() }
            } label: {
                HStack {
                    if let place {
                        PlaceLabel(name: place.name, address: place.address)
                    } else {
                        Label("Choose a place", systemImage: "mappin.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showingChoices ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows other places to choose from")

            if place != nil {
                starButton
            }
        }

        if showingChoices {
            choices
        }

        if let saved, showingStarOptions {
            SavedPlaceOptions(saved: saved) {
                withAnimation {
                    context.delete(saved)
                    showingStarOptions = false
                    addToMyPlaces = false
                }
            }
        } else if saved == nil, addToMyPlaces, place != nil {
            TextField("Nickname for voice, e.g. the store", text: $nickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.leading, 32)
        }
    }

    private var starButton: some View {
        let isStarred = saved != nil || addToMyPlaces
        return Button {
            withAnimation {
                if saved != nil {
                    showingStarOptions.toggle()
                } else {
                    addToMyPlaces.toggle()
                }
            }
        } label: {
            Image(systemName: isStarred ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(isStarred ? .yellow : .secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(saved != nil ? "In My places" : "Add to My places")
        .accessibilityValue(isStarred ? "On" : "Off")
    }

    @ViewBuilder private var choices: some View {
        let current = saved
        let otherSaved = savedPlaces.filter { $0 !== current && !$0.isDeleted }.prefix(3)
        ForEach(otherSaved) { saved in
            choiceButton(saved.place, name: saved.nickname ?? saved.name, systemImage: "star.fill")
        }
        ForEach(results.filter { $0 != place }.prefix(4), id: \.self) { result in
            choiceButton(result, name: result.name, systemImage: "mappin.circle")
        }
        if isSearching {
            ProgressView().frame(maxWidth: .infinity)
        }
        Button {
            showingChoices = false
            onSearch()
        } label: {
            Label("Search for another place", systemImage: "magnifyingglass")
        }
        .padding(.leading, 32)
        .task {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard results.isEmpty, !text.isEmpty else { return }
            isSearching = true
            results = (try? await search.search(text, near: location.current?.coordinate)) ?? []
            isSearching = false
        }
    }

    private func choiceButton(_ choice: PlaceRef, name: String, systemImage: String) -> some View {
        Button {
            withAnimation {
                showingChoices = false
                showingStarOptions = false
                addToMyPlaces = false
            }
            onChoose(choice)
        } label: {
            PlaceLabel(name: name, address: choice.address, systemImage: systemImage)
        }
        .padding(.leading, 32)
    }
}

/// The nickname and remove button for a place already in My places.
private struct SavedPlaceOptions: View {
    @Bindable var saved: SavedPlace
    var onRemove: () -> Void

    var body: some View {
        TextField("Nickname", text: $saved.nicknameText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.leading, 32)
        Button("Remove from My places", systemImage: "star.slash", role: .destructive, action: onRemove)
            .padding(.leading, 32)
    }
}
