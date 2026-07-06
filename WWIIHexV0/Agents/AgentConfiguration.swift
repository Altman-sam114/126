import Foundation

extension GameAgent {
    static func defaultCommander(for faction: Faction, from loader: DataLoader, state: GameState) -> GameAgent {
        if let definition = try? loader.loadGeneralAgents().first(where: { $0.faction == faction.rawValue }),
           let agent = GameAgent(definition: definition) {
            return agent
        }

        if faction == .germany {
            return guderian(from: loader, state: state)
        }

        let assignedIds = state.divisions
            .filter { $0.faction == faction && !$0.isDestroyed }
            .map(\.id)
            .sorted()
        return GameAgent.sample(
            id: "\(faction.rawValue)_general_staff",
            name: "\(faction.commanderDisplayName) General Staff",
            faction: faction,
            role: .generalStaff,
            assignedDivisionIds: assignedIds
        )
    }

    static func guderian(from loader: DataLoader, state: GameState) -> GameAgent {
        if let definition = try? loader.loadGeneralAgents().first(where: { $0.id == "guderian" }),
           let agent = GameAgent(definition: definition) {
            return agent
        }

        return guderianFallback(
            assignedDivisionIds: state.divisions
                .filter { $0.faction == .germany }
                .map(\.id)
                .sorted()
        )
    }

    init?(definition: GeneralAgentDefinition) {
        guard let faction = Faction(rawValue: definition.faction),
              let role = AgentRole(rawValue: definition.role) else {
            return nil
        }

        self.init(
            id: definition.id,
            name: definition.name,
            faction: faction,
            role: role,
            personality: AgentPersonality(
                prompt: definition.personalityPrompt,
                traits: [definition.commandStyle],
                aggression: Self.aggression(for: definition.commandStyle),
                riskTolerance: Self.riskTolerance(for: definition.commandStyle),
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: definition.assignedDivisionIds
        )
    }

    private static func aggression(for commandStyle: String) -> Int {
        switch commandStyle {
        case "aggressive", "breakthrough":
            return 80
        case "cautious":
            return 35
        default:
            return 50
        }
    }

    private static func riskTolerance(for commandStyle: String) -> Int {
        switch commandStyle {
        case "aggressive", "breakthrough":
            return 75
        case "cautious":
            return 35
        default:
            return 50
        }
    }

    static func guderianFallback(assignedDivisionIds: [String]) -> GameAgent {
        GameAgent(
            id: "guderian",
            name: "Heinz Guderian",
            faction: .germany,
            role: .armyCommander,
            personality: AgentPersonality(
                prompt: "Prioritize armored breakthrough, road movement, concentration of force, and rapid encirclement.",
                traits: ["breakthrough"],
                aggression: 80,
                riskTolerance: 75,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds.isEmpty
                ? ["ger_panzer_1", "ger_motorized_1", "ger_infantry_1", "ger_artillery_1"]
                : assignedDivisionIds
        )
    }
}
