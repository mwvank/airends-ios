import SwiftUI
import ErrandKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlements
    @AppStorage(NavigationPreference.storageKey) private var savedNavigationApp: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Places") {
                    NavigationLink("My places") { MyPlacesView() }
                }

                Section("Navigation") {
                    Picker("Navigate with", selection: $savedNavigationApp) {
                        Text("Ask every time").tag("")
                        Text("Google Maps").tag(NavigationApp.googleMaps.rawValue)
                        Text("Apple Maps").tag(NavigationApp.appleMaps.rawValue)
                    }
                }

                Section("Airends Pro") {
                    if entitlements.isUnlocked(.adFree) {
                        Label("Pro is active. Thanks for your support!", systemImage: "checkmark.seal.fill")
                    } else {
                        // StoreKit 2 purchase flow arrives in milestone 6.
                        Label("Remove ads for $3.99/month", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
