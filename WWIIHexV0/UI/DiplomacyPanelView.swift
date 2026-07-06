import SwiftUI

struct DiplomacyPanelView: View {
    let gameState: GameState

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
}
