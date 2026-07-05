import SwiftUI

struct EconomyPanelView: View {
    let gameState: GameState
    let playerFaction: Faction
    let observerModeEnabled: Bool
    let selectedHex: HexCoord?
    let onQueueProduction: (ProductionKind) -> Void
    let onEconomyCommand: (EconomyCommand) -> Void
    let onQueueConstruction: (ConstructionKind, HexCoord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Treasury")
                .font(.headline)

            ledgerSection(for: gameState.activeFaction)

            Divider()

            budgetControls

            Divider()

            constructionControls

            Divider()

            productionControls

            Divider()

            queueSection(for: gameState.activeFaction)
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func ledgerSection(for faction: Faction) -> some View {
        let ledger = gameState.economyState.ledger(for: faction)

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(faction.displayName) Ledger")
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    metric("Recruits", ledger.stockpile.manpower)
                    metric("Treasury", ledger.stockpile.industry)
                    metric("Stores", ledger.stockpile.supplies)
                }

                GridRow {
                    metric("Income REC", ledger.lastIncome.manpower)
                    metric("Income TRE", ledger.lastIncome.industry)
                    metric("Upkeep", ledger.lastUpkeep.supplies)
                }

                GridRow {
                    metric("Debt", ledger.warDebt)
                    metric("Debt Service", ledger.lastUpkeep.industry)
                    metric("Orders", ledger.productionQueue.count + ledger.constructionQueue.count)
                }
            }
        }
    }

    private var budgetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget")
                .font(.subheadline.weight(.semibold))

            ForEach(EconomyCommand.allCases) { command in
                Button {
                    onEconomyCommand(command)
                } label: {
                    Label(command.displayName, systemImage: command.systemImageName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!canApply(command))

                Text(economyCommandSummary(command))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var constructionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Construction")
                .font(.subheadline.weight(.semibold))

            ForEach(ConstructionKind.allCases) { kind in
                Button {
                    if let selectedHex {
                        onQueueConstruction(kind, selectedHex)
                    }
                } label: {
                    Label(constructionButtonTitle(for: kind), systemImage: kind.systemImageName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!canQueue(kind))

                Text(constructionSummary(kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var productionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mobilization")
                .font(.subheadline.weight(.semibold))

            ForEach(ProductionKind.allCases) { kind in
                Button {
                    onQueueProduction(kind)
                } label: {
                    Label(kind.displayName, systemImage: iconName(for: kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(!canQueue(kind))

                Text("Cost \(resourceSummary(kind.cost)) | \(kind.buildTurns) turn(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queueSection(for faction: Faction) -> some View {
        let ledger = gameState.economyState.ledger(for: faction)
        let productionQueue = ledger.productionQueue
        let constructionQueue = ledger.constructionQueue

        return VStack(alignment: .leading, spacing: 6) {
            Text("Orders")
                .font(.subheadline.weight(.semibold))

            if productionQueue.isEmpty && constructionQueue.isEmpty {
                Text("No active orders.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(productionQueue) { order in
                    HStack {
                        Text(order.kind.displayName)
                            .lineLimit(1)
                        Spacer()
                        Text(order.isReady ? "Ready" : "\(order.remainingTurns)")
                            .foregroundStyle(order.isReady ? .green : .secondary)
                    }
                    .font(.caption)
                }

                ForEach(constructionQueue) { order in
                    HStack {
                        Text("\(order.kind.displayName) \(order.target.q),\(order.target.r)")
                            .lineLimit(1)
                        Spacer()
                        Text(order.isReady ? "Ready" : "\(order.remainingTurns)")
                            .foregroundStyle(order.isReady ? .green : .secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func canQueue(_ kind: ProductionKind) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            gameState.economyState.ledger(for: gameState.activeFaction).stockpile.canAfford(kind.cost)
    }

    private func canQueue(_ kind: ConstructionKind) -> Bool {
        guard let selectedHex else {
            return false
        }

        return !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            EconomyRules().canQueueConstruction(
                kind: kind,
                target: selectedHex,
                faction: gameState.activeFaction,
                in: gameState
            )
    }

    private func canApply(_ command: EconomyCommand) -> Bool {
        !observerModeEnabled &&
            activeFactionIsHumanControlled &&
            gameState.phase.isActionPhase &&
            EconomyRules().canApplyEconomyCommand(
                command,
                faction: gameState.activeFaction,
                in: gameState
            )
    }

    private func resourceSummary(_ resources: EconomyResources) -> String {
        resources.victorianSummary
    }

    private var activeFactionIsHumanControlled: Bool {
        gameState.isHumanControlled(gameState.activeFaction) ||
            gameState.activeFaction == playerFaction
    }

    private func economyCommandSummary(_ command: EconomyCommand) -> String {
        var parts = [
            "Cost \(resourceSummary(command.cost))",
            "Yield \(resourceSummary(command.immediateYield))"
        ]
        if command.debtIncrease > 0 {
            parts.append("Debt +\(command.debtIncrease)")
        }
        return parts.joined(separator: " | ")
    }

    private func constructionButtonTitle(for kind: ConstructionKind) -> String {
        guard let selectedHex else {
            return "\(kind.displayName): select hex"
        }
        return "\(kind.displayName) at \(selectedHex.q),\(selectedHex.r)"
    }

    private func constructionSummary(_ kind: ConstructionKind) -> String {
        "Cost \(resourceSummary(kind.cost)) | \(kind.buildTurns) turn(s)"
    }

    private func iconName(for kind: ProductionKind) -> String {
        switch kind {
        case .lineInfantryCorps,
             .infantryDivision:
            return "figure.walk"
        case .guardBrigade,
             .panzerDivision:
            return "shield.lefthalf.filled"
        case .cavalryBrigade,
             .motorizedDivision:
            return "flag"
        case .siegeArtilleryBattery,
             .artilleryDivision:
            return "scope"
        case .supplyConvoy,
             .supplyStockpile:
            return "shippingbox"
        }
    }
}
