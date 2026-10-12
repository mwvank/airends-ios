import Foundation
import Observation
import ErrandKit

/// The user's current tier and the policy that decides what it unlocks.
/// Milestone 6 sets `tier` from StoreKit 2 and `policy` from remote config.
@MainActor
@Observable
final class EntitlementStore {
    var tier: Tier = .free
    var policy: EntitlementPolicy = .launch

    func isUnlocked(_ feature: Feature) -> Bool {
        policy.isUnlocked(feature, for: tier)
    }
}
