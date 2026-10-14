import SwiftUI
import ErrandKit

enum NavigationPreference {
    /// Stores the remembered `NavigationApp` raw value; empty means "ask every time".
    static let storageKey = "navigationApp"
}

/// Asked when a route is started: Google Maps (recommended) or Apple Maps,
/// with "Don't ask again" to remember the choice. Changeable in Settings.
struct NavigationChoiceView: View {
    /// Shown so the user can check where they're about to drive.
    var firstStop: PlaceRef?
    var onChoose: (NavigationApp) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(NavigationPreference.storageKey) private var savedNavigationApp: String = ""
    @State private var dontAskAgain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Navigate with").font(.title2.bold())

            if let firstStop {
                VStack(alignment: .leading, spacing: 2) {
                    Text("First stop").font(.caption).foregroundStyle(.secondary)
                    PlaceLabel(name: firstStop.name, address: firstStop.address)
                }
            }

            choiceButton(
                .googleMaps,
                title: "Google Maps",
                detail: "Recommended. Matches Errandeer's timing, since your plan was built with Google's traffic data."
            )
            choiceButton(
                .appleMaps,
                title: "Apple Maps",
                detail: "Opens directions to your next stop."
            )

            Toggle("Don't ask again", isOn: $dontAskAgain)
            Text("You can change this any time in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func choiceButton(_ app: NavigationApp, title: String, detail: String) -> some View {
        Button {
            if dontAskAgain { savedNavigationApp = app.rawValue }
            dismiss()
            onChoose(app)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
