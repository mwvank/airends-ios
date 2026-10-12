import SwiftUI
import SwiftData
import ErrandKit

/// Shows the errands understood from what the user said, as editable cards,
/// before they're added to today's plan.
struct VoiceReviewView: View {
    let text: String
    var understanding: any ErrandUnderstandingService = OnDeviceErrandUnderstanding()
    var search: any PlaceSearchService = MapKitPlaceSearch()
    var onAdded: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location
    @Query private var savedPlaces: [SavedPlace]
    @Query private var allErrands: [Errand]

    @State private var items: [ReviewItem] = []
    @State private var isWorking = true
    @State private var pickingPlaceFor: ReviewItem?

    var body: some View {
        List {
            Section {
                Text("“\(text)”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("Understanding your errands…").foregroundStyle(.secondary)
                    }
                }
            } else if items.isEmpty {
                ContentUnavailableView("No errands found", systemImage: "questionmark.bubble",
                                       description: Text("Try again, or add errands by typing."))
            } else {
                ForEach($items) { $item in
                    Section {
                        ReviewCard(item: $item, onChoosePlace: { pickingPlaceFor = item }) {
                            items.removeAll { $0.id == item.id }
                        }
                    }
                }
            }
        }
        .navigationTitle("Your errands")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(items.count == 1 ? "Add 1 errand" : "Add \(items.count) errands", action: addAll)
                    .disabled(isWorking || items.isEmpty || items.contains { $0.place == nil })
            }
        }
        .sheet(item: $pickingPlaceFor) { picking in
            PlacePickerView(initialQuery: picking.parsed.placeQuery ?? "", search: search) { place in
                guard let index = items.firstIndex(where: { $0.id == picking.id }) else { return }
                items[index].place = place
                items[index].fromSavedPlaces = false
            }
        }
        .task { if isWorking { await understand() } }
    }

    private func understand() async {
        let parsed = await understanding.understand(text)
        let known = savedPlaces.map { KnownPlace(place: $0.place, nickname: $0.nickname, useCount: $0.useCount) }
        let near = location.current?.coordinate

        var resolved: [ReviewItem] = []
        for errand in parsed {
            var item = ReviewItem(parsed: errand)
            if let query = errand.placeQuery {
                if let match = PlaceResolver.match(query, in: known) {
                    item.place = match
                    item.fromSavedPlaces = true
                } else {
                    item.place = try? await search.search(query, near: near).first
                }
            }
            resolved.append(item)
        }
        items = resolved
        isWorking = false
    }

    private func addAll() {
        var sortIndex = (allErrands.map(\.sortIndex).max() ?? -1) + 1
        for item in items {
            guard let place = item.place else { continue }
            let errand = Errand(
                title: item.parsed.title,
                place: place,
                durationMinutes: item.parsed.durationMinutes,
                fixedStart: item.parsed.fixedTime?.date(on: .now)
            )
            errand.sortIndex = sortIndex
            sortIndex += 1
            context.insert(errand)

            // Learn nicknames: once "the store" is resolved to a place, remember it.
            let nickname = item.parsed.placeQuery.flatMap { PlaceResolver.isNickname($0) && !item.fromSavedPlaces ? $0 : nil }
            SavedPlace.recordUse(of: place, nickname: nickname, in: context)
        }
        onAdded()
        dismiss()
    }
}

struct ReviewItem: Identifiable {
    var parsed: ParsedErrand
    var place: PlaceRef?
    var fromSavedPlaces = false

    var id: UUID { parsed.id }
}

private struct ReviewCard: View {
    @Binding var item: ReviewItem
    var onChoosePlace: () -> Void
    var onRemove: () -> Void

    var body: some View {
        TextField("Errand", text: $item.parsed.title)
            .font(.headline)

        Button(action: onChoosePlace) {
            HStack {
                Label(item.place?.name ?? "Choose a place", systemImage: item.fromSavedPlaces ? "star.fill" : "mappin.circle.fill")
                    .foregroundStyle(item.place == nil ? .orange : .primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }

        Stepper("About \(item.parsed.durationMinutes) min", value: $item.parsed.durationMinutes, in: 5...240, step: 5)

        if let fixed = item.parsed.fixedTime, let date = fixed.date(on: .now) {
            HStack {
                Label("At \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock.fill")
                Spacer()
                Button("Remove") { item.parsed.fixedTime = nil }
                    .font(.caption)
            }
        }

        Button("Remove errand", role: .destructive, action: onRemove)
    }
}
