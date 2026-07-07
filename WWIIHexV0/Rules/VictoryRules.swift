import Foundation

struct VictoryRules {
    func updateVictoryState(in state: inout GameState) {
        guard state.victoryState.winner == nil else {
            return
        }

        if !state.victoryConditions.isEmpty {
            if updateScenarioVictoryState(in: &state) {
                return
            }
            if updateDiplomaticWarGoalVictoryState(in: &state) {
                return
            }
            return
        }

        if updateDiplomaticWarGoalVictoryState(in: &state) {
            return
        }

        let bastogneController = state.map.controllerOfObjective(named: "Bastogne")
        let stVithController = state.map.controllerOfObjective(named: "St. Vith")

        if bastogneController == .germany {
            if let heldSince = state.victoryState.germanBastogneHeldSinceTurn,
               state.turn > heldSince {
                state.victoryState.winner = .germany
                state.victoryState.reason = .bastogneHeldByGermany
                return
            } else if state.victoryState.germanBastogneHeldSinceTurn == nil {
                state.victoryState.germanBastogneHeldSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanBastogneHeldSinceTurn = nil
        }

        if bastogneController == .germany && stVithController == .germany {
            state.victoryState.winner = .germany
            state.victoryState.reason = .bastogneAndStVithControlledByGermany
            return
        }

        if state.victoryState.eliminatedAlliedDivisions >= 3 {
            state.victoryState.winner = .germany
            state.victoryState.reason = .alliedUnitsDestroyed
            return
        }

        if state.victoryState.eliminatedGermanDivisions >= 3 {
            state.victoryState.winner = .allies
            state.victoryState.reason = .germanUnitsDestroyed
            return
        }

        let germanArmor = state.divisions.filter { $0.faction == .germany && $0.isArmor }
        if !germanArmor.isEmpty && germanArmor.allSatisfy({ $0.supplyState != .supplied }) {
            if let since = state.victoryState.germanArmorUnsuppliedSinceTurn,
               state.turn > since {
                state.victoryState.winner = .allies
                state.victoryState.reason = .germanArmorUnsupplied
                return
            } else if state.victoryState.germanArmorUnsuppliedSinceTurn == nil {
                state.victoryState.germanArmorUnsuppliedSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanArmorUnsuppliedSinceTurn = nil
        }

        if state.turn >= state.maxTurns && bastogneController == .allies {
            state.victoryState.winner = .allies
            state.victoryState.reason = .bastogneHeldByAlliesAtFinalTurn
        }
    }

    @discardableResult
    private func updateScenarioVictoryState(in state: inout GameState) -> Bool {
        for condition in state.victoryConditions where condition.status == "win" {
            guard isScenarioConditionSatisfied(condition, in: state) else {
                state.victoryState.conditionSatisfiedSinceTurn[condition.id] = nil
                continue
            }

            switch condition.type {
            case "controlObjective", "controlObjectives":
                resolve(condition, reason: reason(for: condition), in: &state)
                return true
            case "holdObjectives":
                let heldSince = state.victoryState.conditionSatisfiedSinceTurn[condition.id] ?? state.turn
                state.victoryState.conditionSatisfiedSinceTurn[condition.id] = heldSince
                if holdThresholdMet(condition, heldSince: heldSince, turn: state.turn) {
                    resolve(condition, reason: .scenarioObjectivesHeld, in: &state)
                    return true
                }
            default:
                continue
            }
        }
        return false
    }

    @discardableResult
    private func updateDiplomaticWarGoalVictoryState(in state: inout GameState) -> Bool {
        for play in state.diplomacyState.diplomaticPlays
            where play.outcome == .escalatedToWar && !play.warGoal.dynamicVictoryObjectiveGroups.isEmpty {
            let issuerSideFactions = issuerSideFactions(for: play)
            guard play.warGoal.dynamicVictoryObjectiveGroups.contains(where: { objectiveIds in
                objectiveIdsExist(objectiveIds, in: state) &&
                    sideControlsObjectives(
                        objectiveIds,
                        sideFactions: issuerSideFactions,
                        diplomacyState: state.diplomacyState,
                        map: state.map
                    )
            }) else {
                continue
            }

            state.victoryState.winner = play.issuerFaction
            state.victoryState.reason = .diplomaticWarGoalAchieved
            state.victoryState.resolvedConditionId = "diplomatic_\(play.id)"
            return true
        }
        return false
    }

    private func isScenarioConditionSatisfied(_ condition: VictoryCondition, in state: GameState) -> Bool {
        guard !condition.objectiveIds.isEmpty else {
            return false
        }

        switch condition.type {
        case "controlObjective", "controlObjectives", "holdObjectives":
            return condition.objectiveIds.allSatisfy { objectiveId in
                guard let controller = state.map.controllerOfObjective(id: objectiveId) else {
                    return false
                }
                return countsAsObjectiveControl(
                    controller: controller,
                    for: condition.faction,
                    diplomacyState: state.diplomacyState
                )
            }
        default:
            return false
        }
    }

    private func countsAsObjectiveControl(
        controller: Faction,
        for faction: Faction,
        diplomacyState: DiplomacyState
    ) -> Bool {
        guard controller != .neutral, faction != .neutral else {
            return controller == faction
        }
        if controller == faction {
            return true
        }

        switch diplomacyState.relationStatus(between: faction, and: controller) {
        case .allied, .coBelligerent:
            return true
        case .neutral, .hostile, .atWar, .truce, .militaryAccess, .blockaded:
            return false
        }
    }

    private func sideControlsObjectives(
        _ objectiveIds: [String],
        sideFactions: [Faction],
        diplomacyState: DiplomacyState,
        map: MapState
    ) -> Bool {
        objectiveIds.allSatisfy { objectiveId in
            guard let controller = map.controllerOfObjective(id: objectiveId) else {
                return false
            }
            return sideFactions.contains {
                countsAsObjectiveControl(controller: controller, for: $0, diplomacyState: diplomacyState)
            }
        }
    }

    private func objectiveIdsExist(_ objectiveIds: [String], in state: GameState) -> Bool {
        objectiveIds.allSatisfy { state.map.objective(id: $0) != nil }
    }

    private func issuerSideFactions(for play: DiplomaticPlay) -> [Faction] {
        sortedUniqueFactions(play.backers + [play.issuerFaction])
    }

    private func sortedUniqueFactions(_ factions: [Faction]) -> [Faction] {
        Array(Set(factions)).sorted { $0.rawValue < $1.rawValue }
    }

    private func holdThresholdMet(_ condition: VictoryCondition, heldSince: Int, turn: Int) -> Bool {
        if let targetTurn = condition.turn {
            return turn >= targetTurn
        }

        let requiredTurns = max(1, condition.turns ?? 1)
        return turn >= heldSince + requiredTurns - 1
    }

    private func reason(for condition: VictoryCondition) -> VictoryReason {
        switch condition.type {
        case "controlObjective":
            return .scenarioObjectiveControlled
        case "controlObjectives":
            return .scenarioObjectivesControlled
        case "holdObjectives":
            return .scenarioObjectivesHeld
        default:
            return .scenarioObjectivesControlled
        }
    }

    private func resolve(_ condition: VictoryCondition, reason: VictoryReason, in state: inout GameState) {
        state.victoryState.winner = condition.faction
        state.victoryState.reason = reason
        state.victoryState.resolvedConditionId = condition.id
    }
}
