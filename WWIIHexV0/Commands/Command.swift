import Foundation

enum Command: Codable, Equatable {
    case move(divisionId: String, destination: HexCoord)
    case attack(attackerId: String, targetId: String)
    case hold(divisionId: String)
    case allowRetreat(divisionId: String)
    case resupply(divisionId: String)
    case queueProduction(kind: ProductionKind)
    case economy(command: EconomyCommand)
    case diplomacy(command: DiplomacyCommand)
    case queueConstruction(kind: ConstructionKind, target: HexCoord)
    case endTurn

    static func rest(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    static func reinforce(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    var displayName: String {
        switch self {
        case .move(let divisionId, let destination):
            return "Move(\(divisionId) -> \(destination.q),\(destination.r))"
        case .attack(let attackerId, let targetId):
            return "Attack(\(attackerId) -> \(targetId))"
        case .hold(let divisionId):
            return "Hold(\(divisionId))"
        case .allowRetreat(let divisionId):
            return "AllowRetreat(\(divisionId))"
        case .resupply(let divisionId):
            return "Resupply(\(divisionId))"
        case .queueProduction(let kind):
            return "QueueProduction(\(kind.displayName))"
        case .economy(let command):
            return "Economy(\(command.displayName))"
        case .diplomacy(let command):
            return "Diplomacy(\(command.displayName))"
        case .queueConstruction(let kind, let target):
            return "QueueConstruction(\(kind.displayName) @ \(target.q),\(target.r))"
        case .endTurn:
            return "End Turn"
        }
    }

    var actingDivisionId: String? {
        switch self {
        case .move(let divisionId, _),
             .hold(let divisionId),
             .allowRetreat(let divisionId),
             .resupply(let divisionId):
            return divisionId
        case .attack(let attackerId, _):
            return attackerId
        case .queueProduction:
            return nil
        case .economy:
            return nil
        case .diplomacy:
            return nil
        case .queueConstruction:
            return nil
        case .endTurn:
            return nil
        }
    }

    var isRecoveryCommand: Bool {
        switch self {
        case .resupply:
            return true
        case .move,
             .attack,
             .hold,
             .allowRetreat,
             .queueProduction,
             .economy,
             .diplomacy,
             .queueConstruction,
             .endTurn:
            return false
        }
    }
}

enum DiplomaticPlaySupportSide: String, Codable, Equatable, CaseIterable {
    case issuer
    case target

    var displayName: String {
        switch self {
        case .issuer:
            return "Issuer"
        case .target:
            return "Target"
        }
    }
}

enum DiplomacyCommand: Codable, Equatable {
    case declareWar(targetFaction: Faction)
    case imposeBlockade(targetFaction: Faction)
    case createDiplomaticPlay(
        targetFaction: Faction,
        regionId: RegionId?,
        warGoal: DiplomaticPlayWarGoal
    )
    case supportDiplomaticPlay(playId: String, side: DiplomaticPlaySupportSide)
    case respondToDiplomaticPlay(
        playId: String,
        stance: DiplomaticPlayAIStance,
        agentId: String,
        rationale: String
    )
    case offerConcession(playId: String)
    case negotiateTruce(playId: String)

    var displayName: String {
        switch self {
        case .declareWar(let targetFaction):
            return "DeclareWar(\(targetFaction.displayName))"
        case .imposeBlockade(let targetFaction):
            return "ImposeBlockade(\(targetFaction.displayName))"
        case .createDiplomaticPlay(let targetFaction, let regionId, let warGoal):
            let regionDescription = regionId?.rawValue ?? "general"
            return "CreateDiplomaticPlay(\(targetFaction.displayName), \(warGoal.displayName), \(regionDescription))"
        case .supportDiplomaticPlay(let playId, let side):
            return "SupportDiplomaticPlay(\(playId), \(side.displayName))"
        case .respondToDiplomaticPlay(let playId, let stance, let agentId, _):
            return "RespondToDiplomaticPlay(\(playId), \(stance.displayName), \(agentId))"
        case .offerConcession(let playId):
            return "OfferConcession(\(playId))"
        case .negotiateTruce(let playId):
            return "NegotiateTruce(\(playId))"
        }
    }

    var targetFaction: Faction? {
        switch self {
        case .declareWar(let targetFaction):
            return targetFaction
        case .imposeBlockade(let targetFaction):
            return targetFaction
        case .createDiplomaticPlay(let targetFaction, _, _):
            return targetFaction
        case .supportDiplomaticPlay:
            return nil
        case .respondToDiplomaticPlay:
            return nil
        case .offerConcession:
            return nil
        case .negotiateTruce:
            return nil
        }
    }
}
