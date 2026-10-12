import Foundation

/// A place the user has used before, with its optional nickname.
public struct KnownPlace: Hashable, Sendable {
    public var place: PlaceRef
    public var nickname: String?
    public var useCount: Int

    public init(place: PlaceRef, nickname: String? = nil, useCount: Int = 0) {
        self.place = place
        self.nickname = nickname
        self.useCount = useCount
    }
}

/// Matches what the user said ("the store", "CVS") to places they already use,
/// so their usual places are picked without searching.
public enum PlaceResolver {
    public static func match(_ query: String, in known: [KnownPlace]) -> PlaceRef? {
        let wanted = normalize(query)
        guard wanted.count >= 3 else { return nil }
        let byUse = known.sorted { $0.useCount > $1.useCount }

        if let nicknamed = byUse.first(where: { $0.nickname.map(normalize) == wanted }) {
            return nicknamed.place
        }
        return byUse.first { candidate in
            let name = normalize(candidate.place.name)
            return name == wanted || name.hasPrefix(wanted + " ") || wanted.hasPrefix(name + " ")
        }?.place
    }

    /// True when the phrase refers to one of the user's own places ("the store",
    /// "my gym") and is worth remembering as a nickname once resolved.
    public static func isNickname(_ query: String) -> Bool {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        return ["the ", "my ", "our "].contains { lowered.hasPrefix($0) }
    }

    static func normalize(_ text: String) -> String {
        var result = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
            .trimmingCharacters(in: .whitespaces)
        for prefix in ["the ", "my ", "our "] where result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
        }
        return result
    }
}
