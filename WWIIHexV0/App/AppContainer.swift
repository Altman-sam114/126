import Combine
import Foundation

final class AppContainer: ObservableObject {
    @Published private(set) var gameState: GameState
    @Published private(set) var selectedUnitId: String?
    @Published private(set) var selectedHex: HexCoord?
    @Published private(set) var selectedRegionId: RegionId?
    @Published private(set) var movementHighlights: Set<HexCoord>
    @Published private(set) var attackHighlights: Set<HexCoord>
    @Published private(set) var interactionLog: [GameLogEntry]
    @Published private(set) var lastCommandMessage: String?
    @Published private(set) var lastAgentDecisionRecord: AgentDecisionRecord?
    @Published private(set) var lastWarDirectiveRecords: [WarDirectiveRecord]
    @Published private(set) var observerModeEnabled: Bool
    @Published private(set) var mapDisplayLayer: MapDisplayLayer
    @Published private(set) var playerFaction: Faction

    let commandHandler: GameCommandHandling
    let dataLoader: DataLoader
    let generalRegistry: GeneralRegistry
    let warPipelineMode: WarPipelineMode
    let turnManager: TurnManager?
    private let playerFactionOverride: Faction?
    private var isRunningAI = false

    init(
        gameState: GameState,
        commandHandler: GameCommandHandling,
        dataLoader: DataLoader,
        generalRegistry: GeneralRegistry = .empty,
        playerFaction: Faction? = nil,
        turnManager: TurnManager? = nil,
        warPipelineMode: WarPipelineMode = .marshalDirective,
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex
    ) {
        let bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        let assignedState = Self.refreshGeneralAssignments(in: bootstrappedState, registry: generalRegistry)
        self.gameState = assignedState
        self.commandHandler = commandHandler
        self.dataLoader = dataLoader
        self.generalRegistry = generalRegistry
        self.playerFactionOverride = playerFaction
        self.playerFaction = playerFaction ?? Self.defaultPlayerFaction(in: assignedState)
        self.warPipelineMode = warPipelineMode
        self.turnManager = turnManager
        self.selectedUnitId = nil
        self.selectedHex = nil
        self.selectedRegionId = nil
        self.movementHighlights = []
        self.attackHighlights = []
        self.interactionLog = []
        self.lastCommandMessage = nil
        self.lastAgentDecisionRecord = nil
        self.lastWarDirectiveRecords = []
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
    }

    static func bootstrap() -> AppContainer {
        let dataLoader = DataLoader()
        let gameState = dataLoader.loadInitialGameState()
        let commandHandler = RuleEngine()
        let generalRegistry = (try? dataLoader.loadGeneralRegistry()) ?? .empty
        let bootstrappedState = Self.refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(gameState),
            registry: generalRegistry
        )
        let defaultAIFaction = Self.defaultAIFaction(in: bootstrappedState)
        let defaultAgent = GameAgent.defaultCommander(for: defaultAIFaction, from: dataLoader, state: bootstrappedState)
        let turnManager = TurnManager(
            agent: defaultAgent,
            provider: MockAIClient(),
            providerName: "Simulated Staff",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: bootstrappedState, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(agent: defaultAgent, state: bootstrappedState),
            rulerAgent: Self.buildRulerAgent(faction: defaultAIFaction, state: bootstrappedState)
        )
        return AppContainer(
            gameState: bootstrappedState,
            commandHandler: commandHandler,
            dataLoader: dataLoader,
            generalRegistry: generalRegistry,
            turnManager: turnManager,
            warPipelineMode: .marshalDirective
        )
    }

    func submit(_ command: Command) {
        let stateBeforeCommand = gameState
        let result = commandHandler.execute(command, in: gameState)
        var nextState = StrategicStateBootstrapper().bootstrapIfNeeded(result.state)
        if result.succeeded {
            nextState = applyPlayerCommandBookkeeping(
                command,
                to: nextState,
                previousState: stateBeforeCommand
            )
        }
        gameState = refreshGeneralAssignments(in: nextState)
        lastCommandMessage = result.message

        let status = result.succeeded ? "accepted" : "rejected"
        appendInteractionEvent("Command \(status): \(command.displayName). \(result.message)")
        refreshSelectionAfterStateChange()
        runAIIfNeeded()
    }

    func runAIIfNeeded() {
        guard !isRunningAI else {
            return
        }

        gameState = refreshedRuntimeState(gameState)
        guard shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) else {
            return
        }

        isRunningAI = true
        let stateSnapshot = gameState
        let pipelineMode = warPipelineMode
        let observerEnabled = observerModeEnabled

        Task {
            let outcome = await self.runAISequence(
                from: stateSnapshot,
                pipelineMode: pipelineMode,
                observerEnabled: observerEnabled
            )
            await MainActor.run {
                self.gameState = self.refreshedRuntimeState(outcome.state)
                self.lastAgentDecisionRecord = outcome.record
                self.lastWarDirectiveRecords = outcome.directiveRecords
                self.lastCommandMessage = outcome.record.errors.isEmpty
                    ? "AI turn completed."
                    : "AI turn completed with \(outcome.record.errors.count) issue(s)."
                self.appendInteractionEvent("AI \(outcome.record.provider) resolved \(outcome.record.commandResults.count) command result(s).")
                self.isRunningAI = false
                self.refreshSelectionAfterStateChange()
            }
        }
    }

    func handleBoardTap(_ coord: HexCoord) {
        guard gameState.map.contains(coord) else {
            return
        }

        selectedHex = coord
        selectedRegionId = mapDisplayAdapter.regionId(for: coord)
        appendInteractionEvent(selectionMessage(for: coord))

        let displayedDivisions = mapDisplayAdapter.divisions(displayedAt: coord, viewerFaction: commandFaction)
        if let attacker = selectedActionDivision,
           let enemy = displayedDivisions.first(where: { gameState.diplomacyState.canAttack(attacker: attacker.faction, target: $0.faction) }) {
            submit(.attack(attackerId: attacker.id, targetId: enemy.id))
            return
        }

        if let tappedDivision = displayedDivisions.first {
            handleDivisionTap(tappedDivision)
            return
        }

        if let division = selectedActionDivision {
            submitMove(division: division, tappedHex: coord)
        } else {
            selectedUnitId = nil
            clearHighlights()
        }
    }

    func holdSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Hold rejected: no active player-controlled formation selected.")
            return
        }

        submit(.hold(divisionId: division.id))
    }

    func allowRetreatSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Allow retreat rejected: no active player-controlled formation selected.")
            return
        }

        submit(.allowRetreat(divisionId: division.id))
    }

    func resupplySelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("Resupply rejected: no active player-controlled formation selected.")
            return
        }

        submit(.resupply(divisionId: division.id))
    }

    func orderSelectedGeneralHoldLine() {
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("General order rejected: no player command sector selected.")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            defense: DefenseParameters(
                targetReserves: max(1, min(2, zone.unitsDepth.count)),
                stance: .holdLine
            ),
            category: .defense,
            tactic: .holdPosition
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: nil),
            targetRegionId: nil
        )
    }

    func orderSelectedGeneralAttackRegion() {
        guard let target = selectedAttackTarget else {
            appendInteractionEvent("General order rejected: select an enemy front region to attack.")
            return
        }
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("General order rejected: no player source command sector available.")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            attack: AttackParameters(
                targetTheaterId: TheaterId(target.zone.id.rawValue),
                weightedRegions: [target.region.id],
                intensity: .limitedCounter,
                focusRegionId: target.region.id,
                maxCommittedUnits: max(1, min(3, zone.unitsFront.count + zone.unitsDepth.count))
            ),
            category: .offense,
            tactic: .standardAttack,
            commandTarget: .region(target.region.id)
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: target.zone.id),
            targetRegionId: target.region.id
        )
    }

    func queueProduction(_ kind: ProductionKind) {
        guard !observerModeEnabled else {
            appendInteractionEvent("Production rejected: observer mode is read-only.")
            return
        }

        submit(.queueProduction(kind: kind))
    }

    func executeEconomyCommand(_ command: EconomyCommand) {
        guard !observerModeEnabled else {
            appendInteractionEvent("Budget order rejected: observer mode is read-only.")
            return
        }

        submit(.economy(command: command))
    }

    func executeDiplomacyCommand(_ command: DiplomacyCommand) {
        guard !observerModeEnabled else {
            appendInteractionEvent("Diplomacy order rejected: observer mode is read-only.")
            return
        }

        submit(.diplomacy(command: command))
    }

    func queueConstruction(_ kind: ConstructionKind, target: HexCoord) {
        guard !observerModeEnabled else {
            appendInteractionEvent("Construction rejected: observer mode is read-only.")
            return
        }

        submit(.queueConstruction(kind: kind, target: target))
    }

    func endTurn() {
        submit(.endTurn)
    }

    func advanceOrRunAI() {
        if shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) {
            runAIIfNeeded()
        } else {
            endTurn()
        }
    }

    func setObserverModeEnabled(_ enabled: Bool) {
        observerModeEnabled = enabled
    }

    func setMapDisplayLayer(_ layer: MapDisplayLayer) {
        mapDisplayLayer = layer
    }

    func resetGame() {
        isRunningAI = false
        let resetState = refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(dataLoader.loadInitialGameState())
        )
        gameState = resetState
        playerFaction = playerFactionOverride ?? Self.defaultPlayerFaction(in: resetState)
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        movementHighlights = []
        attackHighlights = []
        interactionLog = []
        lastCommandMessage = nil
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = []
    }

    var selectedDivision: Division? {
        guard let selectedUnitId else {
            return nil
        }
        return gameState.division(id: selectedUnitId)
    }

    var selectedRegionInspectorState: RegionInspectorState? {
        guard let selectedRegionId else {
            return nil
        }
        return mapDisplayAdapter.inspectorState(for: selectedRegionId, selectedHex: selectedHex, viewerFaction: commandFaction)
    }

    var selectedUnitInspectorStrategicState: UnitInspectorStrategicState? {
        guard let selectedDivision else {
            return nil
        }
        return mapDisplayAdapter.unitInspectorState(for: selectedDivision)
    }

    var selectedGeneralCommandZone: FrontZone? {
        inferredPlayerCommandZone()
    }

    var selectedGeneral: GeneralData? {
        generalRegistry.general(id: selectedGeneralAssignment?.generalId)
    }

    var selectedGeneralAssignment: GeneralAssignment? {
        selectedGeneralCommandZone?.generalAssignment
    }

    var selectedGeneralAssignedDivisions: [Division] {
        guard let assignment = selectedGeneralAssignment else {
            return []
        }
        let assignedIds = Set(assignment.assignedDivisionIds)
        return gameState.divisions
            .filter { assignedIds.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    var selectedGeneralHQUnderAttack: Bool {
        guard let zone = selectedGeneralCommandZone else {
            return false
        }
        return GeneralDispatcher(registry: generalRegistry).isHQUnderAttack(
            zone: zone,
            map: gameState.map
        )
    }

    var selectedGeneralTargetRegion: RegionNode? {
        selectedRegionId.flatMap { gameState.map.region(id: $0) }
    }

    var selectedGeneralTargetZone: FrontZone? {
        guard let selectedRegionId else {
            return nil
        }
        return gameState.warDeploymentState.zone(for: selectedRegionId)
    }

    var selectedGeneralPlannedOperations: [PlayerPlannedOperation] {
        let zoneId = selectedGeneralCommandZone?.id
        return Array(gameState.playerCommandState.plannedOperations
            .filter { operation in
                operation.turn == gameState.turn &&
                    (zoneId == nil || operation.zoneId == zoneId)
            }
            .suffix(5))
    }

    var canOrderSelectedGeneralHoldLine: Bool {
        canIssuePlayerDirective && selectedGeneralCommandZone != nil
    }

    var canOrderSelectedGeneralAttackRegion: Bool {
        canIssuePlayerDirective && selectedAttackTarget != nil && selectedGeneralCommandZone != nil
    }

    var displayEventLog: [GameLogEntry] {
        Array((gameState.eventLog + interactionLog).suffix(80))
    }

    var commandFaction: Faction {
        currentPlayerCommandFaction ?? playerFaction
    }

    var selectedUnitCanAct: Bool {
        selectedActionDivision != nil
    }

    private var selectedActionDivision: Division? {
        guard !observerModeEnabled else {
            return nil
        }
        guard let commandFaction = currentPlayerCommandFaction else {
            return nil
        }
        guard let division = selectedDivision,
              division.faction == commandFaction,
              !division.hasActed else {
            return nil
        }

        return division
    }

    private var canIssuePlayerDirective: Bool {
        !observerModeEnabled && currentPlayerCommandFaction != nil
    }

    private var currentPlayerCommandFaction: Faction? {
        guard gameState.phase.isActionPhase,
              gameState.activeFaction.participatesInTurnOrder,
              gameState.isHumanControlled(gameState.activeFaction) else {
            return nil
        }
        return gameState.activeFaction
    }

    private var selectedAttackTarget: (region: RegionNode, zone: FrontZone)? {
        guard let commandFaction = currentPlayerCommandFaction else {
            return nil
        }
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId),
              let targetZone = gameState.warDeploymentState.zone(for: selectedRegionId),
              gameState.diplomacyState.canAttack(attacker: commandFaction, target: targetZone.faction) else {
            return nil
        }
        return (region, targetZone)
    }

    private var mapDisplayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }

    private func refreshedRuntimeState(_ state: GameState) -> GameState {
        refreshGeneralAssignments(
            in: StrategicStateBootstrapper().refreshRuntimeState(state)
        )
    }

    private func refreshGeneralAssignments(in state: GameState) -> GameState {
        Self.refreshGeneralAssignments(in: state, registry: generalRegistry)
    }

    private static func refreshGeneralAssignments(
        in state: GameState,
        registry: GeneralRegistry
    ) -> GameState {
        guard !registry.allGenerals.isEmpty else {
            return state
        }
        var next = state
        next.warDeploymentState = GeneralDispatcher(registry: registry).assignGenerals(
            to: state.warDeploymentState,
            map: state.map
        )
        return next
    }

    private static func defaultPlayerFaction(in state: GameState) -> Faction {
        if let configuredHumanFaction = state.turnOrder.first(where: { state.humanControlledFactions.contains($0) }) {
            return configuredHumanFaction
        }
        if let humanFaction = state.humanControlledFactions
            .filter(\.participatesInTurnOrder)
            .sorted(by: { $0.rawValue < $1.rawValue })
            .first {
            return humanFaction
        }
        if state.turnOrder.contains(.allies) {
            return .allies
        }
        return state.turnOrder.first(where: \.participatesInTurnOrder) ?? state.activeFaction
    }

    private static func defaultAIFaction(in state: GameState) -> Faction {
        if let configuredAIFaction = state.turnOrder.first(where: { faction in
            faction.participatesInTurnOrder && !state.humanControlledFactions.contains(faction)
        }) {
            return configuredAIFaction
        }
        if state.activeFaction.participatesInTurnOrder {
            return state.activeFaction
        }
        return state.turnOrder.first(where: \.participatesInTurnOrder) ?? .germany
    }

    private func applyPlayerCommandBookkeeping(
        _ command: Command,
        to state: GameState,
        previousState: GameState
    ) -> GameState {
        var next = state
        if command == .endTurn || next.activeFaction != previousState.activeFaction || next.turn != previousState.turn {
            next.playerCommandState.clearTurnLocks()
            return next
        }

        let commandFaction = previousState.activeFaction
        guard let divisionId = command.actingDivisionId,
              previousState.isHumanControlled(commandFaction),
              previousState.phase.isActionPhase,
              commandFaction.participatesInTurnOrder,
              previousState.division(id: divisionId)?.faction == commandFaction else {
            return next
        }

        next.playerCommandState.lockDivision(divisionId)
        return registerPlayerIntervention(for: divisionId, in: next)
    }

    private func registerPlayerIntervention(for divisionId: String, in state: GameState) -> GameState {
        guard let zoneId = logicalZoneId(for: divisionId, in: state.warDeploymentState),
              var zone = state.warDeploymentState.frontZones[zoneId],
              let assignment = zone.generalAssignment else {
            return state
        }

        var next = state
        zone.generalAssignment = assignment.registeringPlayerIntervention(cost: 2)
        next.warDeploymentState.frontZones[zoneId] = zone
        return next
    }

    private func inferredPlayerCommandZone() -> FrontZone? {
        guard let commandFaction = currentPlayerCommandFaction else {
            return nil
        }

        if let division = selectedDivision,
           division.faction == commandFaction,
           let zoneId = gameState.warDeploymentState.zoneId(for: division.coord, map: gameState.map),
           let zone = gameState.warDeploymentState.frontZones[zoneId],
           zone.faction == commandFaction {
            return zone
        }

        if let selectedRegionId,
           let zone = gameState.warDeploymentState.zone(for: selectedRegionId),
           zone.faction == commandFaction {
            return zone
        }

        guard let targetZone = selectedGeneralTargetZone,
              gameState.diplomacyState.canAttack(attacker: commandFaction, target: targetZone.faction) else {
            return nil
        }

        return playerZonesAdjacent(to: targetZone.id, faction: commandFaction).first
    }

    private func playerZonesAdjacent(to targetZoneId: FrontZoneId, faction: Faction) -> [FrontZone] {
        gameState.warDeploymentState.frontZones.values
            .filter { zone in
                zone.faction == faction &&
                    zone.frontSegments.contains { $0.neighborEnemyZone == targetZoneId }
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func sourceRegionId(for zone: FrontZone, targetZoneId: FrontZoneId?) -> RegionId? {
        if let selectedDivision,
           selectedDivision.faction == zone.faction,
           let regionId = selectedDivision.location(in: gameState.map),
           zone.regionIds.contains(regionId) {
            return regionId
        }

        if let selectedRegionId,
           zone.regionIds.contains(selectedRegionId) {
            return selectedRegionId
        }

        if let targetZoneId,
           let segment = zone.frontSegments
            .filter({ $0.neighborEnemyZone == targetZoneId })
            .sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue })
            .first {
            return segment.regionId
        }

        return zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
    }

    private func logicalZoneId(for divisionId: String, in deploymentState: WarDeploymentState) -> FrontZoneId? {
        deploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first {
                $0.unitsFront.contains(divisionId)
                    || $0.unitsDepth.contains(divisionId)
                    || $0.unitsGarrison.contains(divisionId)
            }?
            .id
    }

    private func submitPlayerDirective(
        _ directive: ZoneDirective,
        sourceRegionId: RegionId?,
        targetRegionId: RegionId?
    ) {
        guard let commandFaction = currentPlayerCommandFaction,
              canIssuePlayerDirective else {
            appendInteractionEvent("General order rejected: not in the player command phase.")
            return
        }
        guard gameState.warDeploymentState.frontZones[directive.zoneId]?.faction == commandFaction else {
            appendInteractionEvent("General order rejected: source zone is not controlled by the player.")
            return
        }

        let startState = refreshedRuntimeState(gameState)
        guard let refreshedZone = startState.warDeploymentState.frontZones[directive.zoneId],
              refreshedZone.faction == commandFaction else {
            appendInteractionEvent("General order rejected: source zone changed during refresh.")
            return
        }
        let lockedIds = startState.playerCommandState.micromanagedDivisionIds
        let execution = WarCommandExecutor(commandHandler: commandHandler).execute(
            directive,
            in: startState,
            excluding: lockedIds
        )

        var nextState = refreshGeneralAssignments(in: execution.finalState)
        let commandSummaries = execution.commandResults.enumerated().map { index, result in
            CommandResultSummary.directiveCommand(
                directiveIndex: 0,
                commandIndex: index,
                directive: directive,
                command: execution.generatedCommands[index],
                result: result
            )
        }
        var diagnostics: [String] = []
        if execution.generatedCommands.isEmpty {
            diagnostics.append("Player directive generated no executable commands.")
        }
        let rejected = commandSummaries.filter { !$0.executed }
        if !rejected.isEmpty {
            diagnostics.append("\(rejected.count) command(s) were rejected by rules.")
        }
        if !lockedIds.isEmpty {
            diagnostics.append("\(lockedIds.count) micromanaged formation(s) excluded.")
        }

        let record = WarDirectiveRecord(
            id: "player_directive_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
            issuerId: "player",
            turn: startState.turn,
            faction: commandFaction,
            zoneId: directive.zoneId,
            directiveType: directive.type,
            targetRegionIds: targetRegionId.map { [$0] } ?? directive.targetRegionIds,
            commandResults: commandSummaries,
            diagnostics: diagnostics,
            category: directive.category,
            tactic: directive.tactic,
            commanderAgentId: refreshedZone.generalAssignment?.generalId,
            commandTarget: directive.commandTarget
        )

        nextState.warDirectiveRecords.append(record)
        nextState.playerCommandState.recordOperation(
            PlayerPlannedOperation(
                id: "player_operation_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
                turn: startState.turn,
                zoneId: directive.zoneId,
                faction: commandFaction,
                directiveType: directive.type,
                sourceRegionId: sourceRegionId,
                targetRegionId: targetRegionId,
                createdByGeneralId: refreshedZone.generalAssignment?.generalId
            )
        )

        gameState = nextState
        lastWarDirectiveRecords = Array((lastWarDirectiveRecords + [record]).suffix(12))
        lastCommandMessage = playerDirectiveMessage(for: execution, diagnostics: diagnostics)
        appendInteractionEvent("General order submitted: \(directive.type.rawValue) \(directive.zoneId.rawValue).")
        refreshSelectionAfterStateChange()
    }

    private func playerDirectiveMessage(
        for execution: WarCommandExecutionResult,
        diagnostics: [String]
    ) -> String {
        let acceptedCount = execution.commandResults.filter(\.succeeded).count
        let totalCount = execution.generatedCommands.count
        if totalCount == 0 {
            return diagnostics.first ?? "General order produced no commands."
        }
        if acceptedCount == totalCount {
            return "General order executed \(acceptedCount) command(s)."
        }
        return "General order executed \(acceptedCount)/\(totalCount) command(s)."
    }

    private func shouldRunAI(for faction: Faction, phase: GamePhase) -> Bool {
        phase.isActionPhase &&
            faction.participatesInTurnOrder &&
            (observerModeEnabled || !gameState.isHumanControlled(faction))
    }

    private func runAISequence(
        from state: GameState,
        pipelineMode: WarPipelineMode,
        observerEnabled: Bool
    ) async -> AgentTurnOutcome {
        var currentState = refreshedRuntimeState(state)
        var lastOutcome: AgentTurnOutcome?
        let maxSteps = observerEnabled ? 2 : 1

        for _ in 0..<maxSteps {
            currentState = refreshedRuntimeState(currentState)
            guard shouldRunAIInSnapshot(state: currentState, observerEnabled: observerEnabled) else {
                break
            }

            let manager = turnManager(for: currentState.activeFaction, state: currentState)
            let outcome = await manager.runAITurn(
                state: currentState,
                faction: currentState.activeFaction,
                pipelineMode: pipelineMode
            )
            currentState = refreshedRuntimeState(outcome.state)
            lastOutcome = AgentTurnOutcome(
                state: currentState,
                record: outcome.record,
                directiveRecords: (lastOutcome?.directiveRecords ?? []) + outcome.directiveRecords
            )
        }

        return lastOutcome ?? AgentTurnOutcome(
            state: currentState,
            record: AgentDecisionRecord(
                id: "agent_noop_turn_\(currentState.turn)",
                turn: currentState.turn,
                agentId: "system",
                provider: "System",
                contextSummary: "No AI faction was active.",
                rawJSON: nil,
                parsedIntent: nil,
                commandResults: [],
                errors: []
            )
        )
    }

    private func shouldRunAIInSnapshot(state: GameState, observerEnabled: Bool) -> Bool {
        state.phase.isActionPhase &&
            state.activeFaction.participatesInTurnOrder &&
            (observerEnabled || !state.isHumanControlled(state.activeFaction))
    }

    private func turnManager(for faction: Faction, state: GameState) -> TurnManager {
        if let turnManager,
           turnManager.agent.faction == faction,
           generalRegistry.allGenerals.isEmpty {
            return turnManager
        }

        let agent = GameAgent.defaultCommander(for: faction, from: dataLoader, state: state)

        return TurnManager(
            agent: agent,
            provider: MockAIClient(),
            providerName: "Simulated Staff",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: state, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(agent: agent, state: state),
            rulerAgent: Self.buildRulerAgent(faction: faction, state: state)
        )
    }

    private static func buildCommanderPool(
        state: GameState,
        registry: GeneralRegistry = .empty
    ) -> TheaterCommanderPool {
        if !registry.allGenerals.isEmpty {
            return GeneralDispatcher(registry: registry).commanderPool(for: state)
        }

        let agents: [any ZoneCommanderProviding] = state.warDeploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { zone in
                let style: ZoneCommanderAgentConfig.CommandStyle = zone.faction == .germany ? .aggressive : .balanced
                let config = ZoneCommanderAgentConfig(
                    id: "auto_\(zone.id.rawValue)",
                    name: "\(zone.faction.commanderDisplayName) Commander (\(zone.id.rawValue))",
                    faction: zone.faction,
                    assignedZoneId: zone.id,
                    skills: [],
                    commandStyle: style
                )
                return ZoneCommanderAgent(config: config)
            }
        return TheaterCommanderPool(commanders: agents)
    }

    private static func buildMarshalAgent(agent: GameAgent, state: GameState) -> MarshalAgent {
        MarshalAgent(config: MarshalAgentConfig.fromCommander(agent, state: state))
    }

    private static func buildRulerAgent(faction: Faction, state: GameState) -> RulerAgent {
        RulerAgent.automatic(for: faction, in: state)
    }

    private func handleDivisionTap(_ division: Division) {
        if observerModeEnabled {
            selectDivision(division)
            appendInteractionEvent("Inspecting formation: \(division.name).")
            return
        }

        if division.faction == commandFaction {
            selectDivision(division)
            appendInteractionEvent("Selected formation: \(division.name).")
            return
        }

        if gameState.isHumanControlled(division.faction) {
            selectDivision(division)
            appendInteractionEvent("Selected friendly formation: \(division.name).")
            return
        }

        if let attacker = selectedActionDivision {
            submit(.attack(attackerId: attacker.id, targetId: division.id))
        } else {
            selectDivision(division)
            appendInteractionEvent("Selected enemy formation: \(division.name).")
        }
    }

    private func selectDivision(_ division: Division) {
        selectedUnitId = division.id
        selectedHex = mapDisplayAdapter.unitDisplayHex(for: division) ?? division.coord
        selectedRegionId = division.location(in: gameState.map)
        refreshHighlights()
    }

    private func refreshSelectionAfterStateChange() {
        if let selectedUnitId,
           gameState.division(id: selectedUnitId) == nil {
            self.selectedUnitId = nil
        }

        if let selectedDivision {
            selectedHex = mapDisplayAdapter.unitDisplayHex(for: selectedDivision) ?? selectedDivision.coord
            selectedRegionId = selectedDivision.location(in: gameState.map)
        }

        refreshHighlights()
    }

    private func refreshHighlights() {
        guard let division = selectedActionDivision else {
            clearHighlights()
            return
        }

        movementHighlights = MovementRules().movementRange(for: division, in: gameState)
        attackHighlights = Set(
            gameState.divisions
                .filter {
                    gameState.diplomacyState.canAttack(attacker: division.faction, target: $0.faction) &&
                        division.coord.distance(to: $0.coord) <= division.range
                }
                .map(\.coord)
        )
    }

    private func clearHighlights() {
        movementHighlights = []
        attackHighlights = []
    }

    private func submitMove(division: Division, tappedHex: HexCoord) {
        submit(.move(divisionId: division.id, destination: tappedHex))
    }

    private func selectionMessage(for coord: HexCoord) -> String {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId) else {
            return "Selected hex \(coord.q),\(coord.r)."
        }
        return "Selected region: \(region.name) (\(selectedRegionId.rawValue))."
    }

    private func appendInteractionEvent(_ message: String) {
        interactionLog.append(
            GameLogEntry(
                turn: gameState.turn,
                faction: gameState.activeFaction,
                phase: gameState.phase,
                message: message,
                createdAt: Date()
            )
        )

        if interactionLog.count > 80 {
            interactionLog.removeFirst(interactionLog.count - 80)
        }
    }

}
