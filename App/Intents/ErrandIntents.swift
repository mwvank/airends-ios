import AppIntents

/// "Hey Siri, plan my day in Errandeer". Siri asks what you need to do,
/// then the app opens with the errands ready to review.
struct PlanMyDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Plan My Day"
    static let description = IntentDescription("Tell Errandeer what you need to do today and get a plan.")
    static let openAppWhenRun = true

    @Parameter(title: "Errands", requestValueDialog: IntentDialog("What do you need to do today?"))
    var errands: String

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingPlanRequest.shared.submit(errands)
        return .result()
    }
}

/// "Hey Siri, add an errand in Errandeer". Siri asks for the errand, then
/// the app opens to confirm the place and add it to today's plan.
struct AddErrandIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Errand"
    static let description = IntentDescription("Add an errand to today's plan.")
    static let openAppWhenRun = true

    @Parameter(title: "Errand", requestValueDialog: IntentDialog("What's the errand?"))
    var errand: String

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingPlanRequest.shared.submit(errand)
        return .result()
    }
}

/// Registers the Siri phrases. They work as soon as the app is installed,
/// and also show up in Shortcuts, Spotlight and the Action Button settings.
/// Apple requires every phrase to include the app name.
struct ErrandShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlanMyDayIntent(),
            phrases: [
                "Plan my day in \(.applicationName)",
                "Plan my errands with \(.applicationName)",
                "\(.applicationName) plan my day"
            ],
            shortTitle: "Plan My Day",
            systemImageName: "map"
        )
        AppShortcut(
            intent: AddErrandIntent(),
            phrases: [
                "Add an errand in \(.applicationName)",
                "Add an errand to \(.applicationName)"
            ],
            shortTitle: "Add Errand",
            systemImageName: "plus.circle"
        )
    }
}
