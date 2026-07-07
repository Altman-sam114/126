import SwiftUI

struct DiplomacyPanelView: View {
    let gameState: GameState
    let playerFaction: Faction
    let observerModeEnabled: Bool
    let onDiplomacyCommand: (DiplomacyCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diplomacy")
                .font(.headline)

            if let rulerRecord = diplomacyState.latestRulerRecord {
                rulerSection(rulerRecord)
                Divider()
            }

            if !gameState.victoryConditions.isEmpty {
                warGoalSection
                Divider()
            }

            diplomaticPlaySection
            Divider()

            crisisActionSection
            Divider()

            countrySection
            Divider()
            blocSection
            Divider()
            relationSection
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var diplomacyState: DiplomacyState {
        gameState.diplomacyState
    }

    private var activeFaction: Faction {
        gameState.activeFaction
    }

    private var visibleDiplomaticPlays: [DiplomaticPlay] {
        let activePlayIds = Set(diplomacyState.activeDiplomaticPlays.map(\.id))
        let unresolvedEscalatedPlays = diplomacyState.diplomaticPlays
            .filter { play in
                play.outcome == .escalatedToWar &&
                    !play.warGoal.dynamicVictoryObjectiveGroups.isEmpty &&
                    gameState.victoryState.resolvedConditionId != "diplomatic_\(play.id)" &&
                    dynamicWarGoalStakeDescription(for: play) != nil
            }
            .sorted { lhs, rhs in
                if lhs.deadlineTurn != rhs.deadlineTurn {
                    return lhs.deadlineTurn < rhs.deadlineTurn
                }
                return lhs.id < rhs.id
            }

        return diplomacyState.activeDiplomaticPlays +
            unresolvedEscalatedPlays.filter { !activePlayIds.contains($0.id) }
    }

    private var warGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenario War Goals")
                .font(.subheadline.weight(.semibold))

            LabeledContent("Crisis") {
                Text(scenarioTitle)
            }
            .font(.caption)

            ForEach(gameState.victoryConditions.filter { $0.status == "win" }) { condition in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(condition.faction.displayName) \(conditionTypeLabel(condition.type))")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(warGoalStatus(condition))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(warGoalStatusColor(condition))
                    }

                    Text(condition.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Objectives: \(objectiveNames(for: condition))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let turns = condition.turns {
                        Text("Hold duration: \(turns) turn(s)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var diplomaticPlaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diplomatic Plays")
                .font(.subheadline.weight(.semibold))

            if visibleDiplomaticPlays.isEmpty {
                Text("No active diplomatic plays.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleDiplomaticPlays) { play in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("\(play.issuerFaction.displayName) -> \(play.targetFaction.displayName)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(diplomaticPlayStatusText(for: play))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(diplomaticPlayStatusColor(for: play))
                        }

                        Text(play.warGoal.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let stakeDescription = dynamicWarGoalStakeDescription(for: play) {
                            Text("Victory stake: \(stakeDescription)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("Backers: \(factionNames(play.backers)) | Opposing: \(factionNames(play.opposingBackers)) | Deadline: turn \(play.deadlineTurn)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ForEach(recentStanceRecords(for: play)) { record in
                            Text("AI: \(record.faction.displayName) \(record.stance.displayName) - \(record.rationale)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if play.outcome == .active {
                            HStack(spacing: 6) {
                                Button {
                                    onDiplomacyCommand(.supportDiplomaticPlay(playId: play.id, side: .issuer))
                                } label: {
                                    Label("Back \(play.issuerFaction.displayName)", systemImage: "person.2")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!canSupport(play, side: .issuer))

                                Button {
                                    onDiplomacyCommand(.supportDiplomaticPlay(playId: play.id, side: .target))
                                } label: {
                                    Label("Back \(play.targetFaction.displayName)", systemImage: "person.2")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(!canSupport(play, side: .target))
                            }

                            Button {
                                onDiplomacyCommand(.offerConcession(playId: play.id))
                            } label: {
                                Label("Offer concession", systemImage: "hand.raised")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!canOfferConcession(in: play))
                        }
                    }
                }
            }
        }
    }

    private var crisisActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crisis Actions")
                .font(.subheadline.weight(.semibold))

            if declarationTargetFactions.isEmpty {
                Text("No crisis targets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(declarationTargetFactions, id: \.self) { targetFaction in
                    Button {
                        onDiplomacyCommand(
                            .createDiplomaticPlay(
                                targetFaction: targetFaction,
                                regionId: nil,
                                warGoal: defaultWarGoal(against: targetFaction)
                            )
                        )
                    } label: {
                        Label("Open diplomatic play against \(targetFaction.displayName)", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canCreateDiplomaticPlay(against: targetFaction))

                    Button {
                        onDiplomacyCommand(.declareWar(targetFaction: targetFaction))
                    } label: {
                        Label("Declare war on \(targetFaction.displayName)", systemImage: "flag")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canDeclareWar(on: targetFaction))

                    Text(declarationSummary(for: targetFaction))
                        .font(.caption)
                        .foregroundStyle(declarationSummaryColor(for: targetFaction))
                }
            }
        }
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Countries")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.countries) { country in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.name)
                            .font(.caption.weight(.semibold))
                        Text("\(country.faction.displayName) | \(country.blocId.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Support")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(country.warSupport)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(warSupportColor(for: country))
                    }
                }
            }
        }
    }

    private var blocSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blocs")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.blocs) { bloc in
                LabeledContent(bloc.name) {
                    Text("\(bloc.memberCountryIds.count) member(s)")
                        .foregroundStyle(bloc.faction == activeFaction ? .primary : .secondary)
                        .font(.caption.monospacedDigit())
                }
                .font(.caption)
            }
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relations")
                .font(.subheadline.weight(.semibold))

            if diplomacyState.relations.isEmpty {
                Text("No diplomatic relations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(diplomacyState.relations) { relation in
                    HStack {
                        Text("\(relation.firstCountryId.rawValue) - \(relation.secondCountryId.rawValue)")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(relation.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(relation.status.isHostile ? .red : .secondary)
                    }
                }
            }
        }
    }

    private func rulerSection(_ record: RulerDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ruler")
                .font(.subheadline.weight(.semibold))
            LabeledContent("Agent") {
                Text(record.rulerAgentId)
            }
            LabeledContent("Posture") {
                Text(record.posture.displayName)
            }
            if let zoneId = record.preferredFrontZoneId {
                LabeledContent("Focus") {
                    Text(zoneId.rawValue)
                }
            }
            Text(record.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var scenarioTitle: String {
        switch gameState.scenarioId {
        case "black_sea_crisis_1853":
            return "Black Sea Crisis 1853"
        case "ardennes_v0":
            return "Legacy Ardennes"
        default:
            return gameState.scenarioId
        }
    }

    private func objectiveNames(for condition: VictoryCondition) -> String {
        let names = condition.objectiveIds.map { objectiveId in
            gameState.map.objective(id: objectiveId)?.name ?? objectiveId
        }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    private func conditionTypeLabel(_ type: String) -> String {
        switch type {
        case "controlObjective", "controlObjectives":
            return "Control Goal"
        case "holdObjectives":
            return "Hold Goal"
        default:
            return "Goal"
        }
    }

    private func warGoalStatus(_ condition: VictoryCondition) -> String {
        if gameState.victoryState.resolvedConditionId == condition.id {
            return "Resolved"
        }
        if gameState.victoryState.conditionSatisfiedSinceTurn[condition.id] != nil {
            return "Holding"
        }
        return "Open"
    }

    private func warGoalStatusColor(_ condition: VictoryCondition) -> Color {
        switch warGoalStatus(condition) {
        case "Resolved":
            return .green
        case "Holding":
            return .orange
        default:
            return .secondary
        }
    }

    private func warSupportColor(for country: CountryProfile) -> Color {
        if country.warSupport < 35 {
            return .red
        }
        if country.warSupport < 60 {
            return .orange
        }
        return country.faction == activeFaction ? .primary : .secondary
    }

    private var activeFactionIsHumanControlled: Bool {
        gameState.isHumanControlled(gameState.activeFaction) ||
            gameState.activeFaction == playerFaction
    }

    private var declarationTargetFactions: [Faction] {
        let profiledFactions = Set(diplomacyState.countries.map(\.faction))
        return profiledFactions
            .filter { targetFaction in
                targetFaction != activeFaction &&
                    targetFaction.participatesInTurnOrder &&
                    !targetFaction.isNeutral
            }
            .sorted { lhs, rhs in
                turnOrderSortIndex(for: lhs) < turnOrderSortIndex(for: rhs)
            }
    }

    private func canCreateDiplomaticPlay(against targetFaction: Faction) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            diplomacyState.canCreateDiplomaticPlay(
                issuerFaction: activeFaction,
                targetFaction: targetFaction,
                regionId: nil,
                turn: gameState.turn
            )
    }

    private func canDeclareWar(on targetFaction: Faction) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            diplomacyState.canDeclareWar(
                actingFaction: activeFaction,
                targetFaction: targetFaction
            )
    }

    private func canOfferConcession(in play: DiplomaticPlay) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            diplomacyState.canOfferConcession(
                actingFaction: activeFaction,
                playId: play.id
            )
    }

    private func canSupport(_ play: DiplomaticPlay, side: DiplomaticPlaySupportSide) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            diplomacyState.canSupportDiplomaticPlay(
                actingFaction: activeFaction,
                playId: play.id,
                side: side
            )
    }

    private func declarationSummary(for targetFaction: Faction) -> String {
        let status = diplomacyState.relationStatus(between: activeFaction, and: targetFaction).displayName
        let targetCountryNames = diplomacyState.countries(for: targetFaction)
            .map(\.name)
            .joined(separator: ", ")
        let countries = targetCountryNames.isEmpty ? targetFaction.displayName : targetCountryNames

        if observerModeEnabled {
            return "Observer mode | \(status) | \(countries)"
        }
        if !activeFactionIsHumanControlled {
            return "Waiting for a human-controlled faction | \(status) | \(countries)"
        }
        if !gameState.phase.isActionPhase {
            return "Action phase required | \(status) | \(countries)"
        }
        if diplomacyState.relationStatus(between: activeFaction, and: targetFaction) == .atWar {
            return "Already at war | \(countries)"
        }
        if !diplomacyState.canDeclareWar(actingFaction: activeFaction, targetFaction: targetFaction) {
            return "Declaration unavailable | \(status) | \(countries)"
        }
        return "\(activeFaction.displayName) -> \(targetFaction.displayName) | \(status) | \(countries)"
    }

    private func defaultWarGoal(against targetFaction: Faction) -> DiplomaticPlayWarGoal {
        switch targetFaction {
        case .russia:
            return .demandDanubianWithdrawal
        case .ottoman:
            return .keepStraitsOpen
        default:
            return .weakenPrestige
        }
    }

    private func factionNames(_ factions: [Faction]) -> String {
        factions.map(\.displayName).joined(separator: ", ")
    }

    private func dynamicWarGoalStakeDescription(for play: DiplomaticPlay) -> String? {
        let groupDescriptions = play.warGoal.dynamicVictoryObjectiveGroups.compactMap { objectiveIds -> String? in
            let objectiveNames = objectiveIds.compactMap {
                gameState.map.objective(id: $0)?.name
            }
            guard objectiveNames.count == objectiveIds.count else {
                return nil
            }
            return objectiveNames.joined(separator: " + ")
        }
        guard !groupDescriptions.isEmpty else {
            return nil
        }
        return groupDescriptions.joined(separator: " or ")
    }

    private func diplomaticPlayStatusText(for play: DiplomaticPlay) -> String {
        switch play.outcome {
        case .active:
            return "\(play.escalation)"
        case .backedDown, .negotiatedSettlement, .escalatedToWar:
            return play.outcome.displayName
        }
    }

    private func diplomaticPlayStatusColor(for play: DiplomaticPlay) -> Color {
        switch play.outcome {
        case .active:
            return play.escalation >= 70 ? .orange : .secondary
        case .escalatedToWar:
            return .red
        case .backedDown, .negotiatedSettlement:
            return .secondary
        }
    }

    private func recentStanceRecords(for play: DiplomaticPlay) -> [DiplomaticPlayStanceRecord] {
        Array(play.aiStanceRecords.suffix(2))
    }

    private func declarationSummaryColor(for targetFaction: Faction) -> Color {
        canDeclareWar(on: targetFaction) ? .primary : .secondary
    }

    private func turnOrderSortIndex(for faction: Faction) -> Int {
        if let index = gameState.turnOrder.firstIndex(of: faction) {
            return index
        }
        return gameState.turnOrder.count + (Faction.allCases.firstIndex(of: faction) ?? 0)
    }
}
