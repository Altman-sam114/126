import Foundation

// Runtime agent identity used for audit records and deterministic fallback context.
// Execution still flows through directive decoders, WarCommandExecutor, and RuleEngine.

enum AgentRole: String, Codable, Equatable, CaseIterable {
    case ruler
    case fieldMarshal
    case armyCommander
    case expeditionaryCommander
    case fieldCommander
    case generalStaff

    var displayName: String {
        switch self {
        case .ruler:
            return "Ruler"
        case .fieldMarshal:
            return "Field Marshal"
        case .armyCommander:
            return "Army Commander"
        case .expeditionaryCommander:
            return "Expeditionary Commander"
        case .fieldCommander:
            return "Field Commander"
        case .generalStaff:
            return "General Staff"
        }
    }
}

struct AgentPersonality: Codable, Equatable {
    var prompt: String
    var traits: [String]
    var aggression: Int
    var riskTolerance: Int
    var autonomy: Int
}

struct AgentRelationship: Codable, Equatable {
    var loyalty: Int
    var trust: Int
    var satisfaction: Int
}

struct GameAgent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var faction: Faction
    var role: AgentRole
    var personality: AgentPersonality
    var relationship: AgentRelationship
    var assignedDivisionIds: [String]

    var canIssueUnitCommands: Bool {
        switch role {
        case .armyCommander, .expeditionaryCommander, .fieldCommander:
            return true
        case .ruler, .fieldMarshal, .generalStaff:
            return false
        }
    }
}

extension GameAgent {
    static func sample(
        id: String,
        name: String,
        faction: Faction,
        role: AgentRole,
        assignedDivisionIds: [String] = []
    ) -> GameAgent {
        GameAgent(
            id: id,
            name: name,
            faction: faction,
            role: role,
            personality: AgentPersonality(
                prompt: "Follow role responsibilities and keep recommendations structured.",
                traits: ["disciplined"],
                aggression: 50,
                riskTolerance: 50,
                autonomy: 50
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds
        )
    }
}
