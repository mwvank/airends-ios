import SwiftUI
import SwiftData

@main
struct ErrandPlannerApp: App {
    @State private var location = LocationService()
    @State private var entitlements = EntitlementStore()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(location)
                .environment(entitlements)
                .onAppear { location.start() }
        }
        .modelContainer(for: [Errand.self, SavedPlace.self])
    }
}
