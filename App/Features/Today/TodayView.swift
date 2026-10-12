import SwiftUI
import SwiftData
import ErrandKit

/// The home screen: today's errands as a timed route the user can reorder
/// by drag and drop, then start in Google Maps or Apple Maps.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(LocationService.self) private var location
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.openURL) private var openURL
    @Query(sort: \Errand.sortIndex) private var allErrands: [Errand]

    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var showingNavigationChoice = false
    @State private var showingDictation = false
    @State private var confirmingClear = false
    @Bindable private var pending = PendingPlanRequest.shared
    @AppStorage(NavigationPreference.storageKey) private var savedNavigationApp: String = ""

    private let scheduler = PlanScheduler(travel: EstimatedTravelTimes())

    private var todaysErrands: [Errand] {
        let today = Calendar.current.startOfDay(for: .now)
        return allErrands.filter { $0.day == today && !$0.isDone }
    }

    private var origin: PlaceRef? {
        if let current = location.current {
            return PlaceRef(name: "Current location", latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
        }
        return todaysErrands.first?.place
    }

    private var plan: DayPlan? {
        guard let origin else { return nil }
        return scheduler.timeline(from: origin, startingAt: .now, stops: todaysErrands.map(\.planStop))
    }

    var body: some View {
        NavigationStack {
            Group {
                if todaysErrands.isEmpty {
                    ContentUnavailableView(
                        "Nothing planned yet",
                        systemImage: "checklist",
                        description: Text("Tap Plan my day and say what you need to do, or add errands by typing.")
                    )
                } else {
                    planList
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { showingAdd = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Clear all errands", systemImage: "trash", role: .destructive) {
                            confirmingClear = true
                        }
                        .disabled(allErrands.isEmpty)
                    }
                }
            }
            .confirmationDialog("Clear all errands?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Clear all errands", role: .destructive, action: clearAll)
            } message: {
                Text("This removes every errand. Your saved places are kept.")
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showingAdd) { AddErrandView(nextSortIndex: (allErrands.map(\.sortIndex).max() ?? -1) + 1) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingDictation) { DictationView(onAdded: optimiseNewErrands) }
            .sheet(item: $pending.request) { request in
                // Errands dictated through Siri.
                NavigationStack { VoiceReviewView(text: request.text, onAdded: optimiseNewErrands) }
            }
            .sheet(isPresented: $showingNavigationChoice) {
                NavigationChoiceView { app in openRoute(in: app) }
                    .presentationDetents([.medium])
            }
        }
    }

    private var planList: some View {
        List {
            if let plan, !plan.warnings.isEmpty {
                Section {
                    ForEach(plan.warnings, id: \.self) { warning in
                        Label(message(for: warning), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section {
                ForEach(todaysErrands) { errand in
                    StopRow(errand: errand, timing: plan?.stops.first { $0.id == errand.id })
                        .swipeActions(edge: .leading) {
                            Button("Done", systemImage: "checkmark") { errand.isDone = true }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) { context.delete(errand) }
                            Button(errand.isLocked ? "Unlock" : "Lock", systemImage: errand.isLocked ? "lock.open" : "lock") {
                                errand.isLocked.toggle()
                            }
                        }
                }
                .onMove(perform: move)
            } header: {
                if let finish = plan?.finish {
                    Text("Done by \(finish.formatted(date: .omitted, time: .shortened))")
                }
            }
            if !entitlements.isUnlocked(.adFree) {
                Section { AdSlotView() }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("Plan my day", systemImage: "mic.fill") { showingDictation = true }
                .buttonStyle(.bordered)
            Spacer()
            Group {
                Button("Optimise", systemImage: "wand.and.stars", action: optimise)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                Button("Start route", systemImage: "car.fill", action: startRoute)
                    .buttonStyle(.borderedProminent)
            }
            .disabled(todaysErrands.isEmpty)
        }
        .padding()
        .background(.bar)
    }

    /// Drag and drop (long-press a stop to pick it up): saves the user's new order. The timeline and warnings update immediately.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = todaysErrands
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, errand) in reordered.enumerated() { errand.sortIndex = index }
    }

    /// Re-orders unlocked stops for the best plan.
    /// Removes every errand to start fresh. Saved places and nicknames stay.
    private func clearAll() {
        for errand in allErrands { context.delete(errand) }
    }

    /// Plans newly dictated errands once the list has picked them up.
    private func optimiseNewErrands() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            optimise()
        }
    }

    private func optimise() {
        guard let origin else { return }
        let best = scheduler.optimised(from: origin, startingAt: .now, stops: todaysErrands.map(\.planStop))
        let byID = Dictionary(uniqueKeysWithValues: todaysErrands.map { ($0.id, $0) })
        for (index, scheduled) in best.stops.enumerated() { byID[scheduled.id]?.sortIndex = index }
    }

    private func startRoute() {
        if let app = NavigationApp(rawValue: savedNavigationApp) {
            openRoute(in: app)
        } else {
            showingNavigationChoice = true
        }
    }

    private func openRoute(in app: NavigationApp) {
        let stops = todaysErrands.map(\.place)
        let url: URL? = switch app {
        // Plans longer than 10 stops are sent in batches; "Send the rest" comes in milestone 3.
        case .googleMaps: NavigationHandoff.googleBatches(stops).first.flatMap(NavigationHandoff.googleMapsURL)
        case .appleMaps: stops.first.flatMap(NavigationHandoff.appleMapsURL)
        }
        if let url { openURL(url) }
    }

    private func message(for warning: PlanWarning) -> String {
        func title(_ id: UUID) -> String { todaysErrands.first { $0.id == id }?.title ?? "A stop" }
        switch warning {
        case .lateForFixed(let id, let by):
            return "\(title(id)): you'd be \(Int((by / 60).rounded(.up))) min late."
        case .closedOnArrival(let id):
            return "\(title(id)): closed by the time you arrive."
        case .closesBeforeDone(let id):
            return "\(title(id)): closes before you'd be done."
        }
    }
}

private struct StopRow: View {
    let errand: Errand
    let timing: ScheduledStop?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(errand.title).font(.headline)
                if errand.isLocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                if errand.fixedStart != nil { Image(systemName: "clock.fill").font(.caption).foregroundStyle(.blue) }
            }
            Text(errand.placeName).font(.subheadline).foregroundStyle(.secondary)
            if let timing {
                Text("Leave \(timing.leaveBy.formatted(date: .omitted, time: .shortened)) · \(Int(timing.travelTime / 60)) min drive · \(errand.durationMinutes) min there")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Placeholder for the AdMob banner (milestone 6). Hidden for Pro users.
private struct AdSlotView: View {
    var body: some View {
        Text("Ad")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 50)
    }
}
