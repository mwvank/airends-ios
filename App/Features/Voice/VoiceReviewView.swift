import SwiftUI
import SwiftData
import ErrandKit

/// Shows the errands understood from what the user said, as editable cards,
/// before they're added to today's plan.
struct VoiceReviewView: View {
    let text: String
    var understanding: any ErrandUnderstandingService = OnDeviceErrandUnderstanding()
    var search: any PlaceSearchService = preferredPlaceSearch()
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
                        ReviewCard(item: $item, search: search, onChoosePlace: { pickingPlaceFor = item }) {
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
                items[index].addToMyPlaces = false
                if items[index].parsed.fixedTime == nil {
                    items[index].parsed.fixedTime = SavedPlace.fixedTime(for: place, in: context)
                }
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
                    if item.parsed.fixedTime == nil {
                        item.parsed.fixedTime = SavedPlace.fixedTime(for: match, in: context)
                    }
                } else {
                    item.place = try? await search.search(query, near: near).first
                    // Offer "the store" as the nickname if the user stars this place.
                    if PlaceResolver.isNickname(query) { item.nickname = query.lowercased() }
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

            // Places are only saved when the user stars them.
            if item.addToMyPlaces && SavedPlace.existing(for: place, in: context) == nil {
                SavedPlace.addToMyPlaces(place, nickname: item.nickname, in: context)
            } else {
                SavedPlace.recordUse(of: place, in: context)
            }
        }
        onAdded()
        dismiss()
    }
}

struct ReviewItem: Identifiable {
    var parsed: ParsedErrand
    var place: PlaceRef?
    var addToMyPlaces = false
    var nickname = ""

    var id: UUID { parsed.id }
}

private struct ReviewCard: View {
    @Binding var item: ReviewItem
    var search: any PlaceSearchService
    @Environment(\.modelContext) private var context
    var onChoosePlace: () -> Void
    var onRemove: () -> Void

    var body: some View {
        TextField("Errand", text: $item.parsed.title)
            .font(.headline)

        ErrandPlaceRow(
            place: item.place,
            query: item.parsed.placeQuery ?? "",
            search: search,
            addToMyPlaces: $item.addToMyPlaces,
            nickname: $item.nickname,
            onChoose: { place in
                item.place = place
                if item.parsed.fixedTime == nil {
                    item.parsed.fixedTime = SavedPlace.fixedTime(for: place, in: context)
                }
            },
            onSearch: onChoosePlace
        )

        DurationStepper(minutes: $item.parsed.durationMinutes)

        FixedTimeRow(time: $item.parsed.fixedTime)

        Button("Remove errand", role: .destructive, action: onRemove)
    }
}

/// How long the user spends at a place, shown as "45 min" or "1 hr 15 min".
struct DurationStepper: View {
    @Binding var minutes: Int

    var body: some View {
        Stepper(value: $minutes, in: 5...240, step: 5) {
            LabeledContent("Time at location:", value: DurationText.format(minutes: minutes))
        }
    }
}

/// A time an errand must start, such as school pickup at 3:00. Errands that can
/// happen any time show only a "Set time" button, which adds one.
struct FixedTimeRow: View {
    @Binding var time: ClockTime?

    var body: some View {
        if let current = time {
            HStack {
                Label("Fixed time:", systemImage: "clock")
                Spacer()
                DatePicker(
                    "Fixed time",
                    selection: Binding(get: { current.date(on: .now) ?? .now }, set: { time = ClockTime($0) }),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                Button {
                    withAnimation { time = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove fixed time")
            }
        } else {
            Button("Set time") {
                withAnimation { time = Self.nextHour() }
            }
            .buttonStyle(.borderless)
        }
    }

    /// The next whole hour, a sensible starting point for the picker.
    static func nextHour(after date: Date = .now) -> ClockTime {
        let hour = Calendar.current.component(.hour, from: date)
        return ClockTime(hour: (hour + 1) % 24, minute: 0)
    }
}
