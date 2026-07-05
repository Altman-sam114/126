import Foundation

enum VictoryReason: String, Codable, Equatable {
    case bastogneHeldByGermany
    case bastogneAndStVithControlledByGermany
    case alliedUnitsDestroyed
    case bastogneHeldByAlliesAtFinalTurn
    case germanUnitsDestroyed
    case germanArmorUnsupplied
    case scenarioObjectiveControlled
    case scenarioObjectivesControlled
    case scenarioObjectivesHeld
}

struct VictoryCondition: Codable, Equatable, Identifiable {
    let id: String
    let type: String
    let faction: Faction
    let objectiveIds: [String]
    let turns: Int?
    let turn: Int?
    let status: String
    let description: String

    init(
        id: String,
        type: String,
        faction: Faction,
        objectiveIds: [String],
        turns: Int? = nil,
        turn: Int? = nil,
        status: String,
        description: String
    ) {
        self.id = id
        self.type = type
        self.faction = faction
        self.objectiveIds = objectiveIds
        self.turns = turns
        self.turn = turn
        self.status = status
        self.description = description
    }
}

struct VictoryState: Codable, Equatable {
    var winner: Faction?
    var reason: VictoryReason?
    var eliminatedGermanDivisions: Int
    var eliminatedAlliedDivisions: Int
    var germanBastogneHeldSinceTurn: Int?
    var germanArmorUnsuppliedSinceTurn: Int?
    var conditionSatisfiedSinceTurn: [String: Int]
    var resolvedConditionId: String?

    static var ongoing: VictoryState {
        VictoryState(
            winner: nil,
            reason: nil,
            eliminatedGermanDivisions: 0,
            eliminatedAlliedDivisions: 0,
            germanBastogneHeldSinceTurn: nil,
            germanArmorUnsuppliedSinceTurn: nil,
            conditionSatisfiedSinceTurn: [:],
            resolvedConditionId: nil
        )
    }

    init(
        winner: Faction?,
        reason: VictoryReason?,
        eliminatedGermanDivisions: Int,
        eliminatedAlliedDivisions: Int,
        germanBastogneHeldSinceTurn: Int?,
        germanArmorUnsuppliedSinceTurn: Int?,
        conditionSatisfiedSinceTurn: [String: Int] = [:],
        resolvedConditionId: String? = nil
    ) {
        self.winner = winner
        self.reason = reason
        self.eliminatedGermanDivisions = eliminatedGermanDivisions
        self.eliminatedAlliedDivisions = eliminatedAlliedDivisions
        self.germanBastogneHeldSinceTurn = germanBastogneHeldSinceTurn
        self.germanArmorUnsuppliedSinceTurn = germanArmorUnsuppliedSinceTurn
        self.conditionSatisfiedSinceTurn = conditionSatisfiedSinceTurn
        self.resolvedConditionId = resolvedConditionId
    }

    private enum CodingKeys: String, CodingKey {
        case winner
        case reason
        case eliminatedGermanDivisions
        case eliminatedAlliedDivisions
        case germanBastogneHeldSinceTurn
        case germanArmorUnsuppliedSinceTurn
        case conditionSatisfiedSinceTurn
        case resolvedConditionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            winner: try container.decodeIfPresent(Faction.self, forKey: .winner),
            reason: try container.decodeIfPresent(VictoryReason.self, forKey: .reason),
            eliminatedGermanDivisions: try container.decodeIfPresent(Int.self, forKey: .eliminatedGermanDivisions) ?? 0,
            eliminatedAlliedDivisions: try container.decodeIfPresent(Int.self, forKey: .eliminatedAlliedDivisions) ?? 0,
            germanBastogneHeldSinceTurn: try container.decodeIfPresent(Int.self, forKey: .germanBastogneHeldSinceTurn),
            germanArmorUnsuppliedSinceTurn: try container.decodeIfPresent(Int.self, forKey: .germanArmorUnsuppliedSinceTurn),
            conditionSatisfiedSinceTurn: try container.decodeIfPresent([String: Int].self, forKey: .conditionSatisfiedSinceTurn) ?? [:],
            resolvedConditionId: try container.decodeIfPresent(String.self, forKey: .resolvedConditionId)
        )
    }

    mutating func recordEliminatedDivision(faction: Faction) {
        switch faction {
        case .germany:
            eliminatedGermanDivisions += 1
        case .allies:
            eliminatedAlliedDivisions += 1
        case .britain, .france, .russia, .ottoman, .austria, .sardinia, .neutral:
            break
        }
    }
}
