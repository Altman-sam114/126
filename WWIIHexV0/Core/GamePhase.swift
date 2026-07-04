import Foundation

enum GamePhase: String, Codable, Equatable, CaseIterable {
    case germanAI
    case alliedPlayer
    case humanAction
    case aiAction
    case resolution
    case diplomacyResolution

    var displayName: String {
        switch self {
        case .germanAI:
            return "Legacy German AI"
        case .alliedPlayer:
            return "Legacy Allied Player"
        case .humanAction:
            return "Human Action"
        case .aiAction:
            return "AI Action"
        case .resolution:
            return "Resolution"
        case .diplomacyResolution:
            return "Diplomacy Resolution"
        }
    }

    var isActionPhase: Bool {
        switch self {
        case .germanAI, .alliedPlayer, .humanAction, .aiAction:
            return true
        case .resolution, .diplomacyResolution:
            return false
        }
    }

    var isLegacyAIPhase: Bool {
        self == .germanAI
    }

    var isLegacyHumanPhase: Bool {
        self == .alliedPlayer
    }

    static func actionPhase(for faction: Faction, humanControlledFactions: Set<Faction>) -> GamePhase {
        humanControlledFactions.contains(faction) ? .humanAction : .aiAction
    }
}
