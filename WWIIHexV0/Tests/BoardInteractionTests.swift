import XCTest
@testable import WWIIHexV0

final class BoardInteractionTests: XCTestCase {
    func testTappingAlliedUnitSelectsItAndCalculatesMovementRange() {
        let container = makeContainer()

        container.handleBoardTap(HexCoord(q: 1, r: 1))

        XCTAssertEqual(container.selectedUnitId, "allied")
        XCTAssertEqual(container.selectedHex, HexCoord(q: 1, r: 1))
        XCTAssertFalse(container.movementHighlights.isEmpty)
    }

    func testTappingEmptyHexSubmitsMoveCommandThroughHandler() {
        let handler = MockCommandHandler()
        let container = makeContainer(handler: handler)
        let origin = HexCoord(q: 1, r: 1)
        let destination = HexCoord(q: 1, r: 2)

        container.handleBoardTap(origin)
        container.handleBoardTap(destination)

        XCTAssertEqual(handler.commands, [.move(divisionId: "allied", destination: destination)])
        XCTAssertEqual(container.gameState.division(id: "allied")?.coord, origin)
    }

    func testTappingRegionHexSubmitsMoveThroughCommandIntentAdapter() {
        let handler = MockCommandHandler()
        let state = RegionRuleTestFixtures.state(
            activeFaction: .allies,
            divisions: [
                RegionRuleTestFixtures.division(id: "allied", faction: .allies, coord: HexCoord(q: 1, r: 0))
            ]
        )
        let container = AppContainer(
            gameState: state,
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: .allies
        )

        container.handleBoardTap(HexCoord(q: 1, r: 0))
        container.handleBoardTap(HexCoord(q: 2, r: 0))

        XCTAssertEqual(handler.commands, [.move(divisionId: "allied", destination: HexCoord(q: 2, r: 0))])
        // MockCommandHandler 不实际移动单位；selectedRegionId 跟随选中单位所在 region（forest_road），而非点击目标。
        XCTAssertEqual(container.selectedRegionId, "forest_road")
    }

    func testTappingEnemyWithAlliedSelectionSubmitsAttackCommand() {
        let handler = MockCommandHandler()
        let container = makeContainer(handler: handler)

        container.handleBoardTap(HexCoord(q: 1, r: 1))
        container.handleBoardTap(HexCoord(q: 2, r: 1))

        XCTAssertEqual(handler.commands, [.attack(attackerId: "allied", targetId: "german")])
    }

    func testEndTurnSubmitsCommandThroughHandler() {
        let handler = MockCommandHandler()
        let container = makeContainer(handler: handler)

        container.endTurn()

        XCTAssertEqual(handler.commands, [.endTurn])
    }

    func testDiplomacyCommandSubmitsThroughHandler() {
        let handler = MockCommandHandler()
        let container = makeContainer(handler: handler)
        let stateBeforeCommand = container.gameState

        container.executeDiplomacyCommand(.declareWar(targetFaction: .germany))
        container.executeDiplomacyCommand(.supportDiplomaticPlay(playId: "play_1", side: .issuer))
        container.executeDiplomacyCommand(.offerConcession(playId: "play_1"))

        XCTAssertEqual(
            handler.commands,
            [
                .diplomacy(command: .declareWar(targetFaction: .germany)),
                .diplomacy(command: .supportDiplomaticPlay(playId: "play_1", side: .issuer)),
                .diplomacy(command: .offerConcession(playId: "play_1"))
            ]
        )
        XCTAssertEqual(container.gameState, stateBeforeCommand)
    }

    func testObserverModeRejectsDiplomacyCommandBeforeHandler() {
        let handler = MockCommandHandler()
        let container = AppContainer(
            gameState: Self.testState(),
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: .allies,
            observerModeEnabled: true
        )

        container.executeDiplomacyCommand(.declareWar(targetFaction: .germany))
        container.executeDiplomacyCommand(.supportDiplomaticPlay(playId: "play_1", side: .issuer))

        XCTAssertTrue(handler.commands.isEmpty)
        XCTAssertTrue(
            container.displayEventLog.contains {
                $0.message == "Diplomacy order rejected: observer mode is read-only."
            }
        )
    }

    func testObserverModeSelectingPlayerUnitIsReadOnly() {
        let handler = MockCommandHandler()
        let container = AppContainer(
            gameState: Self.testState(),
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: .allies,
            observerModeEnabled: true
        )

        container.handleBoardTap(HexCoord(q: 1, r: 1))
        XCTAssertEqual(container.selectedUnitId, "allied")

        container.handleBoardTap(HexCoord(q: 1, r: 2))

        XCTAssertNil(container.selectedUnitId)
        XCTAssertEqual(container.selectedHex, HexCoord(q: 1, r: 2))
        XCTAssertTrue(container.movementHighlights.isEmpty)
        XCTAssertTrue(container.attackHighlights.isEmpty)
        XCTAssertFalse(container.selectedUnitCanAct)
        XCTAssertTrue(handler.commands.isEmpty)
    }

    func testObserverModeSelectingEnemyUnitIsReadOnly() {
        let handler = MockCommandHandler()
        let container = AppContainer(
            gameState: Self.testState(),
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: .allies,
            observerModeEnabled: true
        )

        container.handleBoardTap(HexCoord(q: 2, r: 1))

        XCTAssertEqual(container.selectedUnitId, "german")
        XCTAssertTrue(container.movementHighlights.isEmpty)
        XCTAssertTrue(container.attackHighlights.isEmpty)
        XCTAssertFalse(container.selectedUnitCanAct)
        XCTAssertTrue(handler.commands.isEmpty)
    }

    func testSuccessfulSubmitRefreshesRuntimeDerivedState() {
        var staleState = StrategicStateBootstrapper().refreshRuntimeState(DataLoader().loadInitialGameState())
        staleState.turn = 5
        staleState.frontLineState.lastUpdatedTurn = -1
        staleState.warDeploymentState.lastUpdatedTurn = -1
        XCTAssertFalse(staleState.map.regions.isEmpty)
        XCTAssertFalse(staleState.warDeploymentState.frontZones.isEmpty)

        let handler = StateReturningCommandHandler(stateToReturn: staleState)
        let container = AppContainer(
            gameState: staleState,
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: staleState.activeFaction
        )

        container.submit(.queueProduction(kind: .lineInfantryCorps))

        XCTAssertEqual(handler.commands, [.queueProduction(kind: .lineInfantryCorps)])
        XCTAssertEqual(container.gameState.frontLineState.lastUpdatedTurn, staleState.turn)
        XCTAssertEqual(container.gameState.warDeploymentState.lastUpdatedTurn, staleState.turn)
    }

    private func makeContainer(handler: GameCommandHandling = MockCommandHandler()) -> AppContainer {
        AppContainer(
            gameState: Self.testState(),
            commandHandler: handler,
            dataLoader: DataLoader(),
            playerFaction: .allies
        )
    }

    private static func testState() -> GameState {
        GameState(
            scenarioId: "interaction_test",
            turn: 1,
            maxTurns: 8,
            activeFaction: .allies,
            phase: .alliedPlayer,
            map: basicMap(width: 5, height: 5),
            divisions: [
                Division(
                    id: "allied",
                    name: "Allied Test Division",
                    faction: .allies,
                    coord: HexCoord(q: 1, r: 1),
                    components: [DivisionComponent(type: .infantry, weight: 1.0)]
                ),
                Division(
                    id: "german",
                    name: "German Test Division",
                    faction: .germany,
                    coord: HexCoord(q: 2, r: 1),
                    components: [DivisionComponent(type: .infantry, weight: 1.0)]
                )
            ],
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: []
        )
    }

    private static func basicMap(width: Int, height: Int) -> MapState {
        var tiles: [HexCoord: HexTile] = [:]
        for q in 0..<width {
            for r in 0..<height {
                let coord = HexCoord(q: q, r: r)
                tiles[coord] = HexTile(coord: coord)
            }
        }

        return MapState(width: width, height: height, tiles: tiles, supplySources: [], objectives: [])
    }
}

private final class MockCommandHandler: GameCommandHandling {
    private(set) var commands: [Command] = []

    func execute(_ command: Command, in state: GameState) -> CommandResult {
        commands.append(command)
        return CommandResult(command: command, validation: .valid, state: state, message: "Mock command handled.")
    }
}

private final class StateReturningCommandHandler: GameCommandHandling {
    private(set) var commands: [Command] = []
    let stateToReturn: GameState

    init(stateToReturn: GameState) {
        self.stateToReturn = stateToReturn
    }

    func execute(_ command: Command, in state: GameState) -> CommandResult {
        commands.append(command)
        return CommandResult(command: command, validation: .valid, state: stateToReturn, message: "Mock command handled.")
    }
}
