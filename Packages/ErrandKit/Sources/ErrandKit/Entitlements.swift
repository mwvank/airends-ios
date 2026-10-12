import Foundation

/// Everything that can differ between the free and paid tiers.
///
/// Features ask `EntitlementPolicy` whether they are unlocked instead of
/// checking for Pro directly, so moving a feature between tiers is a
/// configuration change (delivered by remote config), not a code change.
public enum Feature: String, CaseIterable, Codable, Sendable {
    case adFree
    case unlimitedReplans
    case widgets
    case watchApp
    case familySharing
}

public enum Tier: String, Codable, CodingKeyRepresentable, Sendable {
    case free
    case pro
}

public struct EntitlementPolicy: Codable, Hashable, Sendable {
    /// Features available on each tier.
    public var features: [Tier: Set<Feature>]
    /// How many times a day a free user can re-plan (each re-plan costs API calls).
    public var freeDailyReplans: Int

    public init(features: [Tier: Set<Feature>], freeDailyReplans: Int) {
        self.features = features
        self.freeDailyReplans = freeDailyReplans
    }

    /// The launch policy: the whole app is free with ads, and Pro removes ads.
    public static let launch = EntitlementPolicy(
        features: [
            .free: [.widgets, .watchApp],
            .pro: Set(Feature.allCases)
        ],
        freeDailyReplans: 10
    )

    public func isUnlocked(_ feature: Feature, for tier: Tier) -> Bool {
        features[tier, default: []].contains(feature)
    }

    public func canReplan(tier: Tier, replansToday: Int) -> Bool {
        isUnlocked(.unlimitedReplans, for: tier) || replansToday < freeDailyReplans
    }
}
