import Foundation

enum Faction: String, Codable, Equatable, Hashable, CaseIterable {
    case germany
    case allies
    case britain
    case france
    case russia
    case ottoman
    case austria
    case sardinia
    case neutral

    /// Legacy two-side shortcut. New rules should use `DiplomacyState`.
    var opponent: Faction {
        legacyOpponent ?? .neutral
    }

    var legacyOpponent: Faction? {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        case .britain, .france, .russia, .ottoman, .austria, .sardinia, .neutral:
            return nil
        }
    }

    var isLegacyPower: Bool {
        self == .germany || self == .allies
    }

    var isNeutral: Bool {
        self == .neutral
    }

    var participatesInTurnOrder: Bool {
        !isNeutral
    }

    var displayName: String {
        switch self {
        case .germany:
            return "Legacy Germany"
        case .allies:
            return "Legacy Allies"
        case .britain:
            return "Britain"
        case .france:
            return "France"
        case .russia:
            return "Russia"
        case .ottoman:
            return "Ottoman Empire"
        case .austria:
            return "Austria"
        case .sardinia:
            return "Sardinia"
        case .neutral:
            return "Neutral"
        }
    }

    var commanderDisplayName: String {
        switch self {
        case .germany:
            return "German"
        case .allies:
            return "Allied"
        default:
            return displayName
        }
    }

    static let legacyTurnOrder: [Faction] = [.germany, .allies]

    static let victorianMajorPowers: [Faction] = [
        .britain,
        .france,
        .russia,
        .ottoman,
        .austria,
        .sardinia
    ]
}
