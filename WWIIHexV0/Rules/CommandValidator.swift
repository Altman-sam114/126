import Foundation

struct CommandValidator {
    private let movementRules = MovementRules()

    func validate(_ command: Command, in state: GameState) -> CommandValidation {
        switch command {
        case .move(let divisionId, let destination):
            return validateMove(divisionId: divisionId, destination: destination, in: state)
        case .attack(let attackerId, let targetId):
            return validateAttack(attackerId: attackerId, targetId: targetId, in: state)
        case .hold(let divisionId):
            return validateUnitCommand(divisionId: divisionId, in: state)
        case .allowRetreat(let divisionId):
            return validateUnitCommand(divisionId: divisionId, in: state)
        case .resupply(let divisionId):
            return validateRecoveryCommand(divisionId: divisionId, in: state)
        case .queueProduction(let kind):
            return validateProduction(kind: kind, in: state)
        case .economy(let command):
            return validateEconomyCommand(command, in: state)
        case .diplomacy(let command):
            return validateDiplomacyCommand(command, in: state)
        case .queueConstruction(let kind, let target):
            return validateConstruction(kind: kind, target: target, in: state)
        case .endTurn:
            return validateEndTurn(in: state)
        }
    }

    private func validateMove(divisionId: String, destination: HexCoord, in state: GameState) -> CommandValidation {
        let unitValidation = validateUnitCommand(divisionId: divisionId, in: state)
        guard unitValidation.isValid,
              let division = state.division(id: divisionId) else {
            return unitValidation
        }

        guard state.map.contains(destination) else {
            return .invalid(.destinationOutOfBounds)
        }

        guard state.map.tile(at: destination)?.isPassable == true else {
            return .invalid(.noPath)
        }

        if state.division(at: destination) != nil {
            return .invalid(.destinationOccupied)
        }

        if let controller = state.map.tile(at: destination)?.controller,
           controller != division.faction,
           !state.diplomacyState.canAttack(attacker: division.faction, target: controller),
           !state.diplomacyState.canEnterTerritory(faction: division.faction, controller: controller) {
            return .invalid(.invalidTargetFaction)
        }

        if let path = movementRules.shortestPathIgnoringMovement(for: division, to: destination, in: state),
           path.cost > division.movement {
            return .invalid(.insufficientMovement)
        }

        guard movementRules.shortestPath(for: division, to: destination, in: state) != nil else {
            return .invalid(.noPath)
        }

        return .valid
    }

    private func validateAttack(attackerId: String, targetId: String, in state: GameState) -> CommandValidation {
        let unitValidation = validateUnitCommand(divisionId: attackerId, in: state)
        guard unitValidation.isValid,
              let attacker = state.division(id: attackerId) else {
            return unitValidation
        }

        guard let target = state.division(id: targetId) else {
            return .invalid(.targetNotFound)
        }

        guard state.diplomacyState.canAttack(attacker: attacker.faction, target: target.faction) else {
            return .invalid(.invalidTargetFaction)
        }

        guard attacker.coord.distance(to: target.coord) <= attacker.range else {
            return .invalid(.targetOutOfRange)
        }

        return .valid
    }

    private func validateUnitCommand(divisionId: String, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let division = state.division(id: divisionId) else {
            return .invalid(.divisionNotFound)
        }

        guard division.faction == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard !division.hasActed, !division.isRetreating else {
            return .invalid(.alreadyActed)
        }

        guard division.canAct else {
            return .invalid(.alreadyActed)
        }

        return .valid
    }

    private func validateRecoveryCommand(divisionId: String, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let division = state.division(id: divisionId) else {
            return .invalid(.divisionNotFound)
        }

        guard division.faction == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard !division.hasActed, !division.isDestroyed, !division.isRetreating else {
            return .invalid(.alreadyActed)
        }

        return .valid
    }

    private func validateEndTurn(in state: GameState) -> CommandValidation {
        phaseAllowsCommands(in: state) ? .valid : .invalid(.wrongPhase)
    }

    private func validateProduction(kind: ProductionKind, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard EconomyRules().canQueueProduction(kind: kind, faction: state.activeFaction, in: state) else {
            return .invalid(.insufficientResources)
        }

        return .valid
    }

    private func validateEconomyCommand(_ command: EconomyCommand, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard EconomyRules().canApplyEconomyCommand(command, faction: state.activeFaction, in: state) else {
            return .invalid(.insufficientResources)
        }

        return .valid
    }

    private func validateDiplomacyCommand(_ command: DiplomacyCommand, in state: GameState) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        switch command {
        case .declareWar(let targetFaction):
            guard targetFaction != state.activeFaction,
                  targetFaction.participatesInTurnOrder,
                  !targetFaction.isNeutral,
                  !state.diplomacyState.countries(for: state.activeFaction).isEmpty,
                  !state.diplomacyState.countries(for: targetFaction).isEmpty else {
                return .invalid(.invalidTargetFaction)
            }

            guard state.diplomacyState.relationStatus(between: state.activeFaction, and: targetFaction) != .atWar else {
                return .invalid(.alreadyAtWar)
            }

            guard state.diplomacyState.canDeclareWar(
                actingFaction: state.activeFaction,
                targetFaction: targetFaction
            ) else {
                return .invalid(.invalidTargetFaction)
            }
        case .createDiplomaticPlay(let targetFaction, let regionId, _):
            guard targetFaction != state.activeFaction,
                  targetFaction.participatesInTurnOrder,
                  !targetFaction.isNeutral,
                  !state.diplomacyState.countries(for: state.activeFaction).isEmpty,
                  !state.diplomacyState.countries(for: targetFaction).isEmpty else {
                return .invalid(.invalidTargetFaction)
            }

            if let regionId,
               state.map.region(id: regionId) == nil {
                return .invalid(.regionNotFound)
            }

            guard state.diplomacyState.relationStatus(between: state.activeFaction, and: targetFaction) != .atWar else {
                return .invalid(.alreadyAtWar)
            }

            guard state.diplomacyState.canCreateDiplomaticPlay(
                issuerFaction: state.activeFaction,
                targetFaction: targetFaction,
                regionId: regionId
            ) else {
                return .invalid(.diplomaticPlayAlreadyActive)
            }
        case .supportDiplomaticPlay(let playId, let side):
            guard let play = state.diplomacyState.diplomaticPlay(id: playId),
                  play.outcome == .active else {
                return .invalid(.diplomaticPlayNotFound)
            }

            guard state.diplomacyState.relationStatus(between: play.issuerFaction, and: play.targetFaction) != .atWar else {
                return .invalid(.alreadyAtWar)
            }

            guard state.diplomacyState.canSupportDiplomaticPlay(
                actingFaction: state.activeFaction,
                playId: playId,
                side: side
            ) else {
                return .invalid(.diplomaticPlaySupportUnavailable)
            }
        case .offerConcession(let playId):
            guard let play = state.diplomacyState.diplomaticPlay(id: playId),
                  play.outcome == .active else {
                return .invalid(.diplomaticPlayNotFound)
            }

            guard play.issuerFaction == state.activeFaction || play.targetFaction == state.activeFaction else {
                return .invalid(.wrongFaction)
            }

            guard state.diplomacyState.relationStatus(between: play.issuerFaction, and: play.targetFaction) != .atWar else {
                return .invalid(.alreadyAtWar)
            }

            guard state.diplomacyState.canOfferConcession(
                actingFaction: state.activeFaction,
                playId: playId
            ) else {
                return .invalid(.invalidTargetFaction)
            }
        }

        return .valid
    }

    private func validateConstruction(
        kind: ConstructionKind,
        target: HexCoord,
        in state: GameState
    ) -> CommandValidation {
        guard phaseAllowsCommands(in: state) else {
            return .invalid(.wrongPhase)
        }

        guard let tile = state.map.tile(at: target) else {
            return .invalid(.destinationOutOfBounds)
        }

        guard tile.isPassable else {
            return .invalid(.noPath)
        }

        guard tile.controller == state.activeFaction else {
            return .invalid(.wrongFaction)
        }

        guard EconomyRules().constructionSiteIsValid(
            kind: kind,
            target: target,
            faction: state.activeFaction,
            in: state
        ) else {
            return .invalid(.invalidConstructionSite)
        }

        guard EconomyRules().canQueueConstruction(
            kind: kind,
            target: target,
            faction: state.activeFaction,
            in: state
        ) else {
            return .invalid(.insufficientResources)
        }

        return .valid
    }

    private func phaseAllowsCommands(in state: GameState) -> Bool {
        state.phase.isActionPhase && state.activeFaction.participatesInTurnOrder
    }
}
