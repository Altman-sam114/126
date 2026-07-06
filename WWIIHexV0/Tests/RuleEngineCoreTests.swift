import XCTest
@testable import WWIIHexV0

final class RuleEngineCoreTests: XCTestCase {
    func testHexDistanceNeighborsDirectionAndRange() {
        let origin = HexCoord(q: 0, r: 0)

        XCTAssertEqual(origin.distance(to: HexCoord(q: 2, r: -2)), 2)
        XCTAssertEqual(origin.neighbors.count, 6)
        XCTAssertTrue(origin.neighbors.contains(HexCoord(q: 1, r: 0)))
        XCTAssertEqual(origin.direction(to: HexCoord(q: 2, r: -2)), .northEast)
        XCTAssertEqual(origin.coordsWithin(distance: 1).count, 7)
    }

    func testTerrainMovementCostsAndFortressDefense() {
        let rules = MovementRules()
        let plainRoad = HexTile(coord: HexCoord(q: 0, r: 0), baseTerrain: .plain, hasRoad: true)
        let forestRoad = HexTile(coord: HexCoord(q: 1, r: 0), baseTerrain: .forest, hasRoad: true)
        let forest = HexTile(coord: HexCoord(q: 1, r: 0), baseTerrain: .forest)
        let riverPlain = HexTile(
            coord: HexCoord(q: 0, r: 0),
            baseTerrain: .plain,
            riverEdges: [.east]
        )
        let fortress = HexTile(coord: HexCoord(q: 1, r: 0), baseTerrain: .fortress)

        XCTAssertEqual(rules.movementCost(from: plainRoad, to: forestRoad, direction: .east), 1)
        XCTAssertEqual(rules.movementCost(from: plainRoad, to: forest, direction: .east), 2)
        XCTAssertEqual(rules.movementCost(from: riverPlain, to: forest, direction: .east), 4)
        XCTAssertEqual(fortress.baseTerrain.defenseBonus, 4)

        let railStart = HexTile(coord: HexCoord(q: 0, r: 0), baseTerrain: .plain, logisticsTags: [.rail])
        let railMountain = HexTile(coord: HexCoord(q: 1, r: 0), baseTerrain: .mountain, logisticsTags: [.rail])
        XCTAssertEqual(rules.movementCost(from: railStart, to: railMountain, direction: .east), 1)
    }

    func testLegalMoveChangesCoordFacingAndActedState() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
            ]
        )

        let result = RuleEngine().execute(
            .move(divisionId: "a", destination: HexCoord(q: 2, r: 1)),
            in: state
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.division(id: "a")?.coord, HexCoord(q: 2, r: 1))
        XCTAssertEqual(result.state.division(id: "a")?.facing, .east)
        XCTAssertEqual(result.state.division(id: "a")?.hasActed, true)
    }

    func testMovementCannotContinueAfterEnteringEnemyZoneOfControl() {
        let map = Self.basicMap(width: 5, height: 1)
        let allied = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0))
        let german = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 0))
        let state = Self.testState(activeFaction: .allies, map: map, divisions: [allied, german])
        let movementRules = MovementRules()

        XCTAssertNotNil(movementRules.shortestPath(for: allied, to: HexCoord(q: 1, r: 0), in: state))
        XCTAssertNil(movementRules.shortestPath(for: allied, to: HexCoord(q: 3, r: 0), in: state))
    }

    func testIllegalMoveDoesNotChangeState() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1)),
                Self.division(id: "b", faction: .allies, coord: HexCoord(q: 2, r: 1))
            ]
        )

        let result = RuleEngine().execute(
            .move(divisionId: "a", destination: HexCoord(q: 2, r: 1)),
            in: state
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.validation.errors, [.destinationOccupied])
        XCTAssertEqual(result.state, state)
    }

    func testFriendlyOccupiedHexCanBePassedThroughButNotStoppedOn() {
        let map = Self.basicMap(width: 4, height: 1)
        let mover = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0))
        let friendlyBlocker = Self.division(id: "b", faction: .allies, coord: HexCoord(q: 1, r: 0))
        let state = Self.testState(activeFaction: .allies, map: map, divisions: [mover, friendlyBlocker])

        let path = MovementRules().shortestPath(for: mover, to: HexCoord(q: 2, r: 0), in: state)
        XCTAssertEqual(path?.coords, [
            HexCoord(q: 0, r: 0),
            HexCoord(q: 1, r: 0),
            HexCoord(q: 2, r: 0)
        ])
        XCTAssertFalse(MovementRules().movementRange(for: mover, in: state).contains(HexCoord(q: 1, r: 0)))

        let passThroughResult = RuleEngine().execute(.move(divisionId: "a", destination: HexCoord(q: 2, r: 0)), in: state)
        let stopOnFriendlyResult = RuleEngine().execute(.move(divisionId: "a", destination: HexCoord(q: 1, r: 0)), in: state)

        XCTAssertTrue(passThroughResult.succeeded)
        XCTAssertEqual(passThroughResult.state.division(id: "a")?.coord, HexCoord(q: 2, r: 0))
        XCTAssertFalse(stopOnFriendlyResult.succeeded)
        XCTAssertEqual(stopOnFriendlyResult.validation.errors, [.destinationOccupied])
    }

    func testMoveValidationDistinguishesOutOfBoundsNoPathAndInsufficientMovement() {
        let start = HexCoord(q: 0, r: 0)
        let isolatedDestination = HexCoord(q: 2, r: 2)
        let blockedMap = MapState(
            width: 3,
            height: 3,
            tiles: [
                start: HexTile(coord: start),
                isolatedDestination: HexTile(coord: isolatedDestination)
            ],
            supplySources: [],
            objectives: []
        )
        let noPathState = Self.testState(
            activeFaction: .allies,
            map: blockedMap,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: start)
            ]
        )

        let noPath = RuleEngine().execute(
            .move(divisionId: "a", destination: isolatedDestination),
            in: noPathState
        )
        XCTAssertEqual(noPath.validation.errors, [.noPath])

        let insufficientState = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0))
            ]
        )
        let insufficient = RuleEngine().execute(
            .move(divisionId: "a", destination: HexCoord(q: 4, r: 0)),
            in: insufficientState
        )

        XCTAssertEqual(insufficient.validation.errors, [.insufficientMovement])

        let outOfBounds = RuleEngine().execute(
            .move(divisionId: "a", destination: HexCoord(q: 9, r: 9)),
            in: insufficientState
        )
        XCTAssertEqual(outOfBounds.validation.errors, [.destinationOutOfBounds])
    }

    func testAttackCausesDeterministicDamageAndCounterattack() {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let defender = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1))
        let state = Self.testState(activeFaction: .allies, divisions: [attacker, defender])

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.division(id: "g")?.hp, 8)
        XCTAssertEqual(result.state.division(id: "a")?.hp, 9)
        XCTAssertEqual(result.state.division(id: "a")?.hasActed, true)
    }

    func testAttackReducesDefenderStrengthOnly() throws {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let defender = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1))
        let state = Self.testState(activeFaction: .allies, divisions: [attacker, defender])

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        let updatedDefender = try XCTUnwrap(result.state.division(id: "g"))
        XCTAssertTrue(result.succeeded)
        XCTAssertLessThan(updatedDefender.strength, defender.strength)
    }

    func testArtilleryDefenderCannotCounterattackWhenAttackedAtRangeOne() {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let defender = Division.artillery(
            id: "g_artillery",
            name: "g_artillery",
            faction: .germany,
            coord: HexCoord(q: 2, r: 1)
        )
        let state = Self.testState(activeFaction: .allies, divisions: [attacker, defender])

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g_artillery"), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.division(id: "g_artillery")?.hp, 7)
        XCTAssertEqual(result.state.division(id: "a")?.hp, 10)
    }

    func testOutOfRangeAttackIsRejected() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0)),
                Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 0))
            ]
        )

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.validation.errors, [.targetOutOfRange])
        XCTAssertEqual(result.state, state)
    }

    func testAlreadyActedUnitCannotActAgain() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1), hasActed: true)
            ]
        )

        let result = RuleEngine().execute(
            .hold(divisionId: "a"),
            in: state
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.validation.errors, [.alreadyActed])
        XCTAssertEqual(result.state, state)
    }

    func testHoldCommandSetsHoldRetreatModeAndMarksActed() throws {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
            ]
        )

        let result = RuleEngine().execute(.hold(divisionId: "a"), in: state)
        let updated = try XCTUnwrap(result.state.division(id: "a"))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(updated.retreatMode, .hold)
        XCTAssertEqual(updated.hasActed, true)
    }

    func testAllowRetreatCommandSetsRetreatableModeAndMarksActed() throws {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1), retreatMode: .hold)
            ]
        )

        let result = RuleEngine().execute(.allowRetreat(divisionId: "a"), in: state)
        let updated = try XCTUnwrap(result.state.division(id: "a"))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(updated.retreatMode, .retreatable)
        XCTAssertEqual(updated.hasActed, true)
    }

    func testResupplyRestoresSuppliedUnitStrengthAndMarksActed() throws {
        let division = Self.division(
            id: "a",
            faction: .allies,
            coord: HexCoord(q: 0, r: 0),
            hp: 7,
            supplyState: .supplied
        )
        let state = Self.testState(activeFaction: .allies, divisions: [division])

        let result = RuleEngine().execute(.resupply(divisionId: "a"), in: state)
        let recovered = try XCTUnwrap(result.state.division(id: "a"))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(recovered.supplyState, .supplied)
        XCTAssertGreaterThan(recovered.hp, division.hp)
        XCTAssertLessThanOrEqual(recovered.hp, division.maxHP)
        XCTAssertEqual(recovered.hasActed, true)
    }

    func testLowSupplyAndEncircledUnitsDoNotReinforceStrength() throws {
        let lowSupply = Self.division(
            id: "a",
            faction: .allies,
            coord: HexCoord(q: 0, r: 0),
            hp: 7,
            supplyState: .lowSupply
        )
        let encircled = Self.division(
            id: "a",
            faction: .allies,
            coord: HexCoord(q: 0, r: 0),
            hp: 7,
            supplyState: .encircled
        )
        let strainedSupplyMap = Self.basicMap(
            width: 5,
            height: 3,
            supplySources: [
                SupplySource(id: "allied_supply", faction: .allies, coord: HexCoord(q: 3, r: 1))
            ]
        )
        let isolatedMap = Self.basicMap(width: 3, height: 3, supplySources: [])
        let lowSupplyState = Self.testState(activeFaction: .allies, map: strainedSupplyMap, divisions: [lowSupply])
        let encircledState = Self.testState(activeFaction: .allies, map: isolatedMap, divisions: [encircled])

        let lowSupplyResult = RuleEngine().execute(.resupply(divisionId: "a"), in: lowSupplyState)
        let encircledResult = RuleEngine().execute(.resupply(divisionId: "a"), in: encircledState)

        XCTAssertEqual(try XCTUnwrap(lowSupplyResult.state.division(id: "a")).hp, lowSupply.hp)
        XCTAssertEqual(try XCTUnwrap(encircledResult.state.division(id: "a")).hp, encircled.hp)
    }

    func testEndTurnSwitchesFactionAndResetsNewActiveFactionActions() {
        let german = Self.division(
            id: "g",
            faction: .germany,
            coord: HexCoord(q: 4, r: 4),
            hasActed: true
        )
        let allied = Self.division(
            id: "a",
            faction: .allies,
            coord: HexCoord(q: 0, r: 0),
            hasActed: true
        )
        let state = Self.testState(activeFaction: .germany, divisions: [german, allied])

        let result = RuleEngine().execute(.endTurn, in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.activeFaction, .allies)
        XCTAssertEqual(result.state.phase, .alliedPlayer)
        XCTAssertEqual(result.state.turn, 1)
        XCTAssertEqual(result.state.division(id: "a")?.hasActed, false)
        XCTAssertEqual(result.state.division(id: "g")?.hasActed, true)
    }

    func testAttackCanEliminateUnitAndRecordVictoryCounter() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1)),
                Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1), hp: 1)
            ]
        )

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.state.division(id: "g"))
        XCTAssertEqual(result.state.victoryState.eliminatedGermanDivisions, 1)
    }

    func testCaptureCityChangesController() {
        var map = Self.basicMap(width: 5, height: 5)
        let cityCoord = HexCoord(q: 2, r: 1)
        if var tile = map.tile(at: cityCoord) {
            tile.baseTerrain = .city
            tile.controller = .germany
            tile.cityName = "Test City"
            map.setTile(tile)
        }

        let state = Self.testState(
            activeFaction: .allies,
            map: map,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
            ]
        )

        let result = RuleEngine().execute(.move(divisionId: "a", destination: cityCoord), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.map.tile(at: cityCoord)?.controller, .allies)
    }

    func testAlliedMoveCapturesEnemyControlledPlainHex() {
        var map = Self.basicMap(width: 4, height: 1)
        let target = HexCoord(q: 1, r: 0)
        if var tile = map.tile(at: target) {
            tile.controller = .germany
            map.setTile(tile)
        }
        let state = Self.testState(
            activeFaction: .allies,
            map: map,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0))
            ]
        )

        let result = RuleEngine().execute(.move(divisionId: "a", destination: target), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.map.tile(at: target)?.controller, .allies)
    }

    func testCaptureSynchronizesRegionTheaterVisibilityAndFrontLineInSameTurn() throws {
        let fixture = FrontLineTestFixtures.mapAndTheaters(specs: [
            .init(id: "allied_home", faction: .allies, theaterId: FrontLineTestFixtures.theaterA, neighbors: ["front_city"]),
            .init(id: "front_city", faction: .germany, theaterId: FrontLineTestFixtures.theaterB, neighbors: ["allied_home", "german_depth"]),
            .init(id: "german_depth", faction: .germany, theaterId: FrontLineTestFixtures.theaterB, neighbors: ["front_city"])
        ])
        var map = fixture.map
        let target = HexCoord(q: 1, r: 0)
        if var targetTile = map.tile(at: target) {
            targetTile.baseTerrain = .city
            targetTile.cityName = "Front City"
            targetTile.controller = .germany
            map.setTile(targetTile)
        }

        let allied = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 0, r: 0))
        let german = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 0))
        var state = Self.testState(activeFaction: .allies, map: map, divisions: [allied, german])
        state.theaterState = fixture.theaterState
        state.theaterState.initialSnapshot = TheaterInitialSnapshot.capture(from: state.theaterState)
        state.theaterState = TheaterSystem().updateTheaters(
            state: state.theaterState,
            map: state.map,
            divisions: state.divisions,
            turn: state.turn,
            force: true
        )
        state.frontLineState = FrontLineManager().makeInitialState(
            map: state.map,
            theaterState: state.theaterState,
            divisions: state.divisions,
            turn: state.turn
        )
        state.warDeploymentState = WarDeploymentManager().makeInitialState(
            map: state.map,
            theaterState: state.theaterState,
            divisions: state.divisions,
            turn: state.turn
        )

        let result = RuleEngine().execute(.move(divisionId: "a", destination: target), in: state)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.map.tile(at: target)?.controller, .allies)
        XCTAssertEqual(result.state.map.region(id: "front_city")?.controller, .allies)
        XCTAssertEqual(result.state.theaterState.regionToTheater["front_city"], FrontLineTestFixtures.theaterB)
        XCTAssertEqual(result.state.theaterState.dynamicTheaterId(for: target, map: result.state.map), FrontLineTestFixtures.theaterA)
        XCTAssertEqual(result.state.theaterState.initialSnapshot?.regionToTheater["front_city"], FrontLineTestFixtures.theaterB)
        XCTAssertGreaterThan(result.state.theaterState.theaters[FrontLineTestFixtures.theaterA]?.controlRatios[.allies] ?? 0, 0)
        XCTAssertEqual(result.state.frontLineState.diagnostics.updateMode, .eventDriven)
        XCTAssertTrue(result.state.frontLineState.diagnostics.updatedRegionIds.contains("front_city"))
        XCTAssertEqual(result.state.frontLineState.regionStates["front_city"]?.dirtyFlag, true)
        XCTAssertLessThan(
            RegionVisibilityRules().visibleRegions(for: .allies, in: result.state, radius: 0).count,
            result.state.map.regions.count
        )
    }

    func testAgentContextDoesNotTreatEmptyVisibilityAsAllVisible() {
        let fixture = FrontLineTestFixtures.mapAndTheaters(specs: [
            .init(id: "a", faction: .allies, theaterId: FrontLineTestFixtures.theaterA, neighbors: ["b"]),
            .init(id: "b", faction: .germany, theaterId: FrontLineTestFixtures.theaterB, neighbors: ["a"])
        ])
        let state = Self.testState(activeFaction: .allies, map: fixture.map, divisions: [])
        let agent = GameAgent.sample(id: "observer", name: "Observer", faction: .allies, role: .armyCommander)

        let context = AgentContextBuilder().agentContext(for: agent, state: state, playerDirective: nil)

        XCTAssertFalse(context.visibleRegions.contains { $0.visible })
    }

    func testUnsuppliedUnitBecomesLowSupplyOrEncircled() throws {
        var map = Self.basicMap(width: 7, height: 7)
        map.supplySources = [SupplySource(id: "allied_supply", faction: .allies, coord: HexCoord(q: 0, r: 0))]

        let state = Self.testState(
            activeFaction: .germany,
            map: map,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 6, r: 6)),
                Self.division(id: "g", faction: .germany, coord: HexCoord(q: 5, r: 6))
            ]
        )

        var next = state
        SupplyRules().updateSupplyStates(in: &next)

        let supplyState = try XCTUnwrap(next.division(id: "a")?.supplyState)
        XCTAssertTrue([SupplyState.lowSupply, .encircled].contains(supplyState))
    }

    func testSupplyModifiersReduceDerivedStatsAndEncirclementAttritionPreservesOneHP() {
        var lowSupply = Self.division(id: "low", faction: .allies, coord: HexCoord(q: 1, r: 1))
        lowSupply.supplyState = .lowSupply
        XCTAssertEqual(lowSupply.attack, 3)
        XCTAssertEqual(lowSupply.defense, 4)
        XCTAssertEqual(lowSupply.movement, 2)

        var encircled = Self.division(id: "encircled", faction: .allies, coord: HexCoord(q: 2, r: 2), hp: 1)
        encircled.supplyState = .encircled
        XCTAssertEqual(encircled.attack, 2)
        XCTAssertEqual(encircled.defense, 3)
        XCTAssertEqual(encircled.movement, 1)

        var state = Self.testState(activeFaction: .allies, divisions: [encircled])
        SupplyRules().applyEncirclementAttrition(in: &state)
        XCTAssertEqual(state.division(id: "encircled")?.hp, 1)
    }

    func testEncircledEndTurnAppliesStrengthAttrition() throws {
        let encircled = Self.division(
            id: "a",
            faction: .allies,
            coord: HexCoord(q: 1, r: 1),
            hp: 6,
            supplyState: .encircled
        )
        let isolatedMap = Self.basicMap(width: 3, height: 3, supplySources: [])
        let state = Self.testState(activeFaction: .allies, map: isolatedMap, divisions: [encircled])

        let result = RuleEngine().execute(.endTurn, in: state)

        let updated = try XCTUnwrap(result.state.division(id: "a"))
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(updated.supplyState, .encircled)
        XCTAssertLessThan(updated.hp, encircled.hp)
        XCTAssertGreaterThanOrEqual(updated.hp, 1)
    }

    func testRetreatableDivisionAutoRetreatsAfterSevereLoss() throws {
        var map = Self.basicMap(
            width: 5,
            height: 5,
            supplySources: [
                SupplySource(id: "german_supply", faction: .germany, coord: HexCoord(q: 4, r: 2)),
                SupplySource(id: "allied_supply", faction: .allies, coord: HexCoord(q: 0, r: 2))
            ]
        )
        if var germanSupplyTile = map.tile(at: HexCoord(q: 4, r: 2)) {
            germanSupplyTile.hasRoad = true
            map.setTile(germanSupplyTile)
        }
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 2))
        let defender = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 2), hp: 4)
        let state = Self.testState(activeFaction: .allies, map: map, divisions: [attacker, defender])
        let expectedDestination = try XCTUnwrap(SupplyRules().retreatDestination(for: defender, in: state))

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        let retreated = try XCTUnwrap(result.state.division(id: "g"))
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(retreated.coord, expectedDestination)
        XCTAssertTrue(result.state.eventLog.contains { $0.message.localizedCaseInsensitiveContains("retreat") })
    }

    func testRetreatableDivisionDoesNotRetreatAfterMinorLoss() throws {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let defender = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1), hp: 10)
        let state = Self.testState(activeFaction: .allies, divisions: [attacker, defender])

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        let updated = try XCTUnwrap(result.state.division(id: "g"))
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(updated.coord, defender.coord)
        XCTAssertFalse(updated.isRetreating)
    }

    func testHoldModeDoesNotRetreatAndTakesExtraLosses() throws {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let retreatable = Self.division(id: "r", faction: .germany, coord: HexCoord(q: 2, r: 1), hp: 10)
        let hold = Self.division(id: "h", faction: .germany, coord: HexCoord(q: 2, r: 1), hp: 10, retreatMode: .hold)
        let retreatableState = Self.testState(activeFaction: .allies, divisions: [attacker, retreatable])
        let holdState = Self.testState(activeFaction: .allies, divisions: [attacker, hold])

        let retreatableResult = RuleEngine().execute(.attack(attackerId: "a", targetId: "r"), in: retreatableState)
        let holdResult = RuleEngine().execute(.attack(attackerId: "a", targetId: "h"), in: holdState)

        let retreatableAfter = try XCTUnwrap(retreatableResult.state.division(id: "r"))
        let holdAfter = try XCTUnwrap(holdResult.state.division(id: "h"))
        XCTAssertEqual(holdAfter.coord, hold.coord)
        XCTAssertFalse(holdAfter.isRetreating)
        XCTAssertLessThanOrEqual(holdAfter.hp, retreatableAfter.hp)
    }

    func testRetreatFailureLogsAndAppliesStrengthPenalty() throws {
        let attacker = Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1))
        let defender = Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1), hp: 4)
        let isolatedMap = Self.basicMap(width: 4, height: 4, supplySources: [])
        let state = Self.testState(activeFaction: .allies, map: isolatedMap, divisions: [attacker, defender])

        let result = RuleEngine().execute(.attack(attackerId: "a", targetId: "g"), in: state)

        let updated = try XCTUnwrap(result.state.division(id: "g"))
        let logText = result.state.eventLog.map(\.message).joined(separator: "\n").lowercased()

        XCTAssertEqual(updated.coord, defender.coord)
        XCTAssertLessThan(updated.hp, defender.hp)
        XCTAssertTrue(logText.contains("failed to retreat"))
    }

    func testBastogneGermanControlRequiresFullTurnBeforeVictory() {
        var state = Self.testState(
            activeFaction: .germany,
            map: MapState.ardennesV0(),
            divisions: []
        )
        if var bastogne = state.map.tile(at: HexCoord(q: 5, r: 4)) {
            bastogne.controller = .germany
            state.map.setTile(bastogne)
        }

        VictoryRules().updateVictoryState(in: &state)
        XCTAssertNil(state.victoryState.winner)
        XCTAssertEqual(state.victoryState.germanBastogneHeldSinceTurn, 1)

        VictoryRules().updateVictoryState(in: &state)
        XCTAssertNil(state.victoryState.winner)

        state.turn = 2
        VictoryRules().updateVictoryState(in: &state)
        XCTAssertEqual(state.victoryState.winner, .germany)
        XCTAssertEqual(state.victoryState.reason, .bastogneHeldByGermany)
    }

    func testGermanArmorUnsuppliedRequiresFullTurnBeforeAlliedVictory() {
        var panzer = Division.panzer(
            id: "g_panzer",
            name: "g_panzer",
            faction: .germany,
            coord: HexCoord(q: 2, r: 2)
        )
        panzer.supplyState = .lowSupply
        var state = Self.testState(activeFaction: .allies, divisions: [panzer])

        VictoryRules().updateVictoryState(in: &state)
        XCTAssertNil(state.victoryState.winner)
        XCTAssertEqual(state.victoryState.germanArmorUnsuppliedSinceTurn, 1)

        VictoryRules().updateVictoryState(in: &state)
        XCTAssertNil(state.victoryState.winner)

        state.turn = 2
        VictoryRules().updateVictoryState(in: &state)
        XCTAssertEqual(state.victoryState.winner, .allies)
        XCTAssertEqual(state.victoryState.reason, .germanArmorUnsupplied)
    }

    func testBlackSeaVictoryConditionsLoadIntoGameState() {
        let state = DataLoader().loadInitialGameState()

        XCTAssertEqual(state.scenarioId, "black_sea_crisis_1853")
        XCTAssertEqual(state.victoryConditions.count, 3)
        XCTAssertTrue(state.victoryConditions.contains { $0.id == "victory_allied_sevastopol" })
    }

    func testBlackSeaLogisticsTagsLoadIntoMap() {
        let state = DataLoader().loadInitialGameState()

        XCTAssertEqual(state.scenarioId, "black_sea_crisis_1853")
        XCTAssertTrue(state.map.hasLogisticsTag(.port, at: HexCoord(q: 2, r: 4)))
        XCTAssertTrue(state.map.hasLogisticsTag(.rail, at: HexCoord(q: 4, r: 7)))
        XCTAssertTrue(state.map.hasLogisticsTag(.siegeDepot, at: HexCoord(q: 7, r: 3)))
    }

    func testCoalitionPortCanAnchorSupplyButMilitaryAccessDoesNot() {
        var coalitionMap = Self.basicMap(width: 3, height: 1, supplySources: [])
        coalitionMap.setTile(
            HexTile(
                coord: HexCoord(q: 0, r: 0),
                controller: .france,
                logisticsTags: [.port]
            )
        )
        let british = Self.division(id: "british", faction: .britain, coord: HexCoord(q: 2, r: 0))
        let coalitionState = Self.testState(
            activeFaction: .britain,
            map: coalitionMap,
            diplomacyState: DiplomacyState.initial(
                for: [.britain, .france, .russia, .ottoman, .austria, .sardinia],
                scenarioId: "black_sea_crisis_1853",
                turn: 1
            ),
            divisions: [british]
        )

        XCTAssertTrue(SupplyRules().hasSupplyLine(for: british, in: coalitionState))

        var accessMap = Self.basicMap(width: 3, height: 1, supplySources: [])
        accessMap.setTile(
            HexTile(
                coord: HexCoord(q: 0, r: 0),
                controller: .ottoman,
                logisticsTags: [.port]
            )
        )
        let austrian = Self.division(id: "austrian", faction: .austria, coord: HexCoord(q: 2, r: 0))
        let accessState = Self.testState(
            activeFaction: .austria,
            map: accessMap,
            diplomacyState: DiplomacyState.initial(
                for: [.britain, .france, .russia, .ottoman, .austria, .sardinia],
                scenarioId: "black_sea_crisis_1853",
                turn: 1
            ),
            divisions: [austrian]
        )

        XCTAssertFalse(SupplyRules().hasSupplyLine(for: austrian, in: accessState))
    }

    func testBlackSeaCoalitionControlCanSatisfyScenarioVictory() throws {
        var state = DataLoader().loadInitialGameState()
        let sevastopol = try XCTUnwrap(state.map.objective(id: "obj_sevastopol")?.coord)
        let varna = try XCTUnwrap(state.map.objective(id: "obj_varna")?.coord)

        if var sevastopolTile = state.map.tile(at: sevastopol) {
            sevastopolTile.controller = .france
            state.map.setTile(sevastopolTile)
        }
        if var varnaTile = state.map.tile(at: varna) {
            varnaTile.controller = .ottoman
            state.map.setTile(varnaTile)
        }

        VictoryRules().updateVictoryState(in: &state)

        XCTAssertEqual(state.victoryState.winner, .britain)
        XCTAssertEqual(state.victoryState.reason, .scenarioObjectivesControlled)
        XCTAssertEqual(state.victoryState.resolvedConditionId, "victory_allied_sevastopol")
    }

    func testDiplomacyCommandCodableRoundTrip() throws {
        let command = Command.diplomacy(command: .declareWar(targetFaction: .austria))
        let playCommand = Command.diplomacy(
            command: .createDiplomaticPlay(
                targetFaction: .austria,
                regionId: "region_danube_delta",
                warGoal: .demandDanubianWithdrawal
            )
        )
        let concessionCommand = Command.diplomacy(command: .offerConcession(playId: "play_1"))

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(Command.self, from: data)
        let playData = try JSONEncoder().encode(playCommand)
        let decodedPlay = try JSONDecoder().decode(Command.self, from: playData)
        let concessionData = try JSONEncoder().encode(concessionCommand)
        let decodedConcession = try JSONDecoder().decode(Command.self, from: concessionData)

        XCTAssertEqual(decoded, command)
        XCTAssertEqual(decodedPlay, playCommand)
        XCTAssertEqual(decodedConcession, concessionCommand)
        XCTAssertNil(command.actingDivisionId)
        XCTAssertNil(playCommand.actingDivisionId)
        XCTAssertNil(concessionCommand.actingDivisionId)
        XCTAssertFalse(command.isRecoveryCommand)
        XCTAssertFalse(playCommand.isRecoveryCommand)
        XCTAssertFalse(concessionCommand.isRecoveryCommand)
    }

    func testCreateDiplomaticPlayRecordsCrisisWithoutOpeningWar() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .humanAction
        let originalMap = state.map
        let originalDivisions = state.divisions
        let originalFrontLineState = state.frontLineState
        let originalWarDeploymentState = state.warDeploymentState

        XCTAssertEqual(state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)
        XCTAssertTrue(state.diplomacyState.activeDiplomaticPlays.isEmpty)

        let result = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: state
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.map, originalMap)
        XCTAssertEqual(result.state.divisions, originalDivisions)
        XCTAssertEqual(result.state.frontLineState, originalFrontLineState)
        XCTAssertEqual(result.state.warDeploymentState, originalWarDeploymentState)
        XCTAssertEqual(result.state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)
        XCTAssertFalse(result.state.diplomacyState.canAttack(attacker: .britain, target: .austria))
        XCTAssertEqual(result.state.diplomacyState.activeDiplomaticPlays.count, 1)

        let play = result.state.diplomacyState.activeDiplomaticPlays[0]
        XCTAssertEqual(play.issuerFaction, .britain)
        XCTAssertEqual(play.targetFaction, .austria)
        XCTAssertNil(play.regionId)
        XCTAssertEqual(play.warGoal, .weakenPrestige)
        XCTAssertEqual(play.escalation, 20)
        XCTAssertEqual(play.backers, [.britain])
        XCTAssertEqual(play.opposingBackers, [.austria])
        XCTAssertEqual(play.createdTurn, state.turn)
        XCTAssertEqual(play.deadlineTurn, state.turn + 3)
        XCTAssertEqual(play.outcome, .active)
        XCTAssertTrue(
            result.state.eventLog.contains {
                $0.category == .diplomacy &&
                    $0.relatedRecordId == play.id &&
                    $0.message == "Britain opened a diplomatic play against Austria: Weaken prestige in the wider crisis."
            }
        )
    }

    func testCreateDiplomaticPlayRejectsDuplicatesAtWarAndWrongPhase() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .humanAction
        let command = Command.diplomacy(
            command: .createDiplomaticPlay(
                targetFaction: .austria,
                regionId: nil,
                warGoal: .weakenPrestige
            )
        )

        let created = RuleEngine().execute(command, in: state)
        XCTAssertTrue(created.succeeded)

        let duplicate = RuleEngine().execute(command, in: created.state)
        XCTAssertFalse(duplicate.succeeded)
        XCTAssertEqual(duplicate.validation.errors, [.diplomaticPlayAlreadyActive])
        XCTAssertEqual(duplicate.state, created.state)

        let atWar = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .russia,
                    regionId: nil,
                    warGoal: .demandDanubianWithdrawal
                )
            ),
            in: state
        )
        XCTAssertFalse(atWar.succeeded)
        XCTAssertEqual(atWar.validation.errors, [.alreadyAtWar])

        state.phase = .diplomacyResolution
        let wrongPhase = RuleEngine().execute(command, in: state)
        XCTAssertFalse(wrongPhase.succeeded)
        XCTAssertEqual(wrongPhase.validation.errors, [.wrongPhase])
        XCTAssertTrue(wrongPhase.state.diplomacyState.activeDiplomaticPlays.isEmpty)
    }

    func testOfferConcessionSettlesDiplomaticPlayWithoutOpeningWar() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .humanAction

        let created = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: state
        )
        XCTAssertTrue(created.succeeded)
        let play = created.state.diplomacyState.activeDiplomaticPlays[0]
        let originalMap = created.state.map
        let originalDivisions = created.state.divisions
        let originalFrontLineState = created.state.frontLineState
        let originalWarDeploymentState = created.state.warDeploymentState
        let originalRelations = created.state.diplomacyState.relations
        let originalCountries = created.state.diplomacyState.countries
        let originalEconomyState = created.state.economyState

        let settled = RuleEngine().execute(
            .diplomacy(command: .offerConcession(playId: play.id)),
            in: created.state
        )

        XCTAssertTrue(settled.succeeded)
        XCTAssertEqual(settled.state.map, originalMap)
        XCTAssertEqual(settled.state.divisions, originalDivisions)
        XCTAssertEqual(settled.state.frontLineState, originalFrontLineState)
        XCTAssertEqual(settled.state.warDeploymentState, originalWarDeploymentState)
        XCTAssertEqual(settled.state.diplomacyState.relations, originalRelations)
        XCTAssertEqual(settled.state.diplomacyState.countries, originalCountries)
        XCTAssertEqual(settled.state.economyState, originalEconomyState)
        XCTAssertEqual(settled.state.diplomacyState.diplomaticPlay(id: play.id)?.outcome, .negotiatedSettlement)
        XCTAssertTrue(settled.state.diplomacyState.activeDiplomaticPlays.isEmpty)
        XCTAssertEqual(settled.state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)
        XCTAssertFalse(settled.state.diplomacyState.canAttack(attacker: .britain, target: .austria))
        XCTAssertEqual(settled.state.diplomacyState.lastUpdatedTurn, state.turn)
        XCTAssertTrue(
            settled.state.eventLog.contains {
                $0.category == .diplomacy &&
                    $0.relatedRecordId == play.id &&
                    $0.message == "Britain offered concessions to Austria, settling the diplomatic play: Weaken prestige."
            }
        )

        let reopened = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: settled.state
        )
        XCTAssertTrue(reopened.succeeded)
        XCTAssertNotEqual(reopened.state.diplomacyState.activeDiplomaticPlays.first?.id, play.id)
    }

    func testOfferConcessionRejectsMissingWrongFactionAndAtWarPlay() {
        let missingState = Self.diplomaticPlayTestState()
        let missing = RuleEngine().execute(
            .diplomacy(command: .offerConcession(playId: "missing_play")),
            in: missingState
        )
        XCTAssertFalse(missing.succeeded)
        XCTAssertEqual(missing.validation.errors, [.diplomaticPlayNotFound])
        XCTAssertEqual(missing.state, missingState)

        let created = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: Self.diplomaticPlayTestState()
        )
        XCTAssertTrue(created.succeeded)
        let play = created.state.diplomacyState.activeDiplomaticPlays[0]

        var wrongFactionState = created.state
        wrongFactionState.activeFaction = .russia
        wrongFactionState.turnOrder = [.britain, .austria, .russia]
        let wrongFaction = RuleEngine().execute(
            .diplomacy(command: .offerConcession(playId: play.id)),
            in: wrongFactionState
        )
        XCTAssertFalse(wrongFaction.succeeded)
        XCTAssertEqual(wrongFaction.validation.errors, [.wrongFaction])
        XCTAssertEqual(wrongFaction.state, wrongFactionState)

        let atWar = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .austria)),
            in: created.state
        )
        XCTAssertTrue(atWar.succeeded)
        let concessionAfterWar = RuleEngine().execute(
            .diplomacy(command: .offerConcession(playId: play.id)),
            in: atWar.state
        )
        XCTAssertFalse(concessionAfterWar.succeeded)
        XCTAssertEqual(concessionAfterWar.validation.errors, [.alreadyAtWar])
        XCTAssertEqual(concessionAfterWar.state, atWar.state)
    }

    func testDiplomaticPlayAdvancesOnlyAfterFullTurnCycle() {
        let created = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: Self.diplomaticPlayTestState()
        )
        XCTAssertTrue(created.succeeded)

        let afterBritishEndTurn = RuleEngine().execute(.endTurn, in: created.state)
        XCTAssertTrue(afterBritishEndTurn.succeeded)
        XCTAssertEqual(afterBritishEndTurn.state.turn, 1)
        XCTAssertEqual(afterBritishEndTurn.state.activeFaction, .austria)
        XCTAssertEqual(afterBritishEndTurn.state.diplomacyState.activeDiplomaticPlays.first?.escalation, 20)
        XCTAssertEqual(afterBritishEndTurn.state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)

        let afterFullCycle = RuleEngine().execute(.endTurn, in: afterBritishEndTurn.state)
        XCTAssertTrue(afterFullCycle.succeeded)
        XCTAssertEqual(afterFullCycle.state.turn, 2)
        XCTAssertEqual(afterFullCycle.state.activeFaction, .britain)
        XCTAssertEqual(afterFullCycle.state.diplomacyState.activeDiplomaticPlays.first?.escalation, 45)
        XCTAssertEqual(afterFullCycle.state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)
        XCTAssertTrue(
            afterFullCycle.state.eventLog.contains {
                $0.category == .diplomacy &&
                    $0.message == "Diplomatic play Weaken prestige escalated to 45; deadline turn 4."
            }
        )
    }

    func testDiplomaticPlayDeadlineEscalatesToWar() {
        let created = RuleEngine().execute(
            .diplomacy(
                command: .createDiplomaticPlay(
                    targetFaction: .austria,
                    regionId: nil,
                    warGoal: .weakenPrestige
                )
            ),
            in: Self.diplomaticPlayTestState()
        )
        XCTAssertTrue(created.succeeded)

        var state = created.state
        while state.turn < 4 {
            state = RuleEngine().execute(.endTurn, in: state).state
        }

        let play = state.diplomacyState.diplomaticPlays.first
        XCTAssertEqual(play?.outcome, .escalatedToWar)
        XCTAssertEqual(play?.escalation, 100)
        XCTAssertTrue(state.diplomacyState.activeDiplomaticPlays.isEmpty)
        XCTAssertEqual(state.diplomacyState.relationStatus(between: .britain, and: .austria), .atWar)
        XCTAssertTrue(state.diplomacyState.canAttack(attacker: .britain, target: .austria))
        XCTAssertEqual(state.diplomacyState.lastUpdatedTurn, 4)
        XCTAssertTrue(
            state.eventLog.contains {
                $0.category == .diplomacy &&
                    $0.relatedRecordId == play?.id &&
                    $0.message == "Diplomatic play Weaken prestige escalated to war: Britain against Austria."
            }
        )

        let concessionAfterDeadlineWar = RuleEngine().execute(
            .diplomacy(command: .offerConcession(playId: play?.id ?? "missing_play")),
            in: state
        )
        XCTAssertFalse(concessionAfterDeadlineWar.succeeded)
        XCTAssertEqual(concessionAfterDeadlineWar.validation.errors, [.diplomaticPlayNotFound])
        XCTAssertEqual(concessionAfterDeadlineWar.state, state)
    }

    func testDiplomaticPlayDeadlineKeepsActiveWhenWarDeclarationFails() {
        let play = DiplomaticPlay(
            id: "play_missing_countries",
            issuerFaction: .britain,
            targetFaction: .austria,
            regionId: nil,
            warGoal: .weakenPrestige,
            backers: [.britain],
            opposingBackers: [.austria],
            createdTurn: 1,
            deadlineTurn: 2
        )
        var diplomacy = DiplomacyState(
            countries: [],
            blocs: [],
            relations: [],
            rulerRecords: [],
            diplomaticPlays: [play],
            lastUpdatedTurn: 1
        )

        let records = diplomacy.advanceDiplomaticPlays(turn: 2)

        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(records[0].didEscalateToWar)
        XCTAssertEqual(records[0].outcome, .active)
        XCTAssertEqual(records[0].escalation, 100)
        XCTAssertEqual(diplomacy.diplomaticPlays.first?.outcome, .active)
        XCTAssertEqual(diplomacy.diplomaticPlays.first?.escalation, 100)
        XCTAssertTrue(diplomacy.activeDiplomaticPlays.contains { $0.id == play.id })
        XCTAssertEqual(diplomacy.relationStatus(between: .britain, and: .austria), .neutral)
    }

    func testDiplomacyStateDecodesLegacyJSONWithoutDiplomaticPlays() throws {
        let data = Data(
            """
            {
              "countries": [],
              "blocs": [],
              "relations": [],
              "rulerRecords": [],
              "lastUpdatedTurn": 2
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(DiplomacyState.self, from: data)

        XCTAssertTrue(decoded.countries.isEmpty)
        XCTAssertTrue(decoded.blocs.isEmpty)
        XCTAssertTrue(decoded.relations.isEmpty)
        XCTAssertTrue(decoded.rulerRecords.isEmpty)
        XCTAssertTrue(decoded.diplomaticPlays.isEmpty)
        XCTAssertEqual(decoded.lastUpdatedTurn, 2)
    }

    func testDeclareWarCommandUpdatesDiplomacyAndAllowsAttack() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .humanAction
        let originalMap = state.map
        let originalDivisions = state.divisions

        XCTAssertEqual(state.diplomacyState.relationStatus(between: .britain, and: .austria), .neutral)

        let result = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .austria)),
            in: state
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.state.map, originalMap)
        XCTAssertEqual(result.state.divisions, originalDivisions)
        XCTAssertEqual(result.state.diplomacyState.relationStatus(between: .britain, and: .austria), .atWar)
        XCTAssertTrue(result.state.diplomacyState.canAttack(attacker: .britain, target: .austria))
        XCTAssertEqual(result.state.diplomacyState.lastUpdatedTurn, state.turn)
        XCTAssertTrue(
            result.state.eventLog.contains {
                $0.category == .diplomacy && $0.message == "Britain declared war on Austria."
            }
        )
        XCTAssertFalse(result.state.frontLineState.frontLines.isEmpty)
        XCTAssertFalse(result.state.warDeploymentState.frontZones.isEmpty)
    }

    func testDeclareWarEnablesAttackWithoutDirectlyMovingUnits() {
        let british = Self.division(id: "british", faction: .britain, coord: HexCoord(q: 1, r: 1))
        let austrian = Self.division(id: "austrian", faction: .austria, coord: HexCoord(q: 2, r: 1))
        let state = Self.testState(
            activeFaction: .britain,
            map: Self.basicMap(width: 4, height: 4),
            diplomacyState: DiplomacyState.initial(for: [.britain, .austria], turn: 1),
            divisions: [british, austrian]
        )

        let before = RuleEngine().execute(.attack(attackerId: "british", targetId: "austrian"), in: state)
        XCTAssertFalse(before.succeeded)
        XCTAssertEqual(before.validation.errors, [.invalidTargetFaction])

        let declared = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .austria)),
            in: state
        )
        XCTAssertTrue(declared.succeeded)
        XCTAssertEqual(declared.state.division(id: "british")?.coord, british.coord)
        XCTAssertEqual(declared.state.division(id: "austrian")?.coord, austrian.coord)

        let after = RuleEngine().execute(.attack(attackerId: "british", targetId: "austrian"), in: declared.state)
        XCTAssertTrue(after.succeeded)
    }

    func testDeclareWarRejectsInvalidTargetsAndDuplicates() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .humanAction

        let duplicate = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .russia)),
            in: state
        )
        XCTAssertFalse(duplicate.succeeded)
        XCTAssertEqual(duplicate.validation.errors, [.alreadyAtWar])

        let selfTarget = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .britain)),
            in: state
        )
        XCTAssertFalse(selfTarget.succeeded)
        XCTAssertEqual(selfTarget.validation.errors, [.invalidTargetFaction])

        let neutralTarget = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .neutral)),
            in: state
        )
        XCTAssertFalse(neutralTarget.succeeded)
        XCTAssertEqual(neutralTarget.validation.errors, [.invalidTargetFaction])
    }

    func testDeclareWarRejectedOutsideActionPhaseDoesNotModifyDiplomacy() {
        var state = DataLoader().loadInitialGameState()
        state.activeFaction = .britain
        state.phase = .diplomacyResolution
        let originalDiplomacy = state.diplomacyState

        let result = RuleEngine().execute(
            .diplomacy(command: .declareWar(targetFaction: .austria)),
            in: state
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.validation.errors, [.wrongPhase])
        XCTAssertEqual(result.state.diplomacyState, originalDiplomacy)
        XCTAssertFalse(result.state.diplomacyState.canAttack(attacker: .britain, target: .austria))
    }

    func testDeclareWarUpdatesAllCountryPairsForFactionRelation() {
        var diplomacy = DiplomacyState(
            countries: [
                CountryProfile(
                    id: "britain",
                    name: "British Empire",
                    faction: .britain,
                    blocId: "british_bloc",
                    rulerAgentId: "ruler_britain"
                ),
                CountryProfile(
                    id: "british_india",
                    name: "British India",
                    faction: .britain,
                    blocId: "british_bloc",
                    rulerAgentId: "ruler_india"
                ),
                CountryProfile(
                    id: "austria",
                    name: "Austrian Empire",
                    faction: .austria,
                    blocId: "austrian_bloc",
                    rulerAgentId: "ruler_austria"
                )
            ],
            blocs: [],
            relations: [],
            lastUpdatedTurn: 1
        )

        XCTAssertTrue(diplomacy.declareWar(actingFaction: .britain, targetFaction: .austria, turn: 3))

        XCTAssertEqual(diplomacy.relationStatus(between: .britain, and: .austria), .atWar)
        XCTAssertEqual(diplomacy.lastUpdatedTurn, 3)
        XCTAssertEqual(diplomacy.relations.count, 2)
        XCTAssertTrue(diplomacy.relations.allSatisfy { $0.status == .atWar && $0.tension == 100 && $0.sinceTurn == 3 })
        XCTAssertNotNil(diplomacy.relation(between: "britain", and: "austria"))
        XCTAssertNotNil(diplomacy.relation(between: "british_india", and: "austria"))
    }

    func testInvalidCommandDoesNotModifyGameState() {
        let state = Self.testState(
            activeFaction: .allies,
            divisions: [
                Self.division(id: "a", faction: .allies, coord: HexCoord(q: 1, r: 1)),
                Self.division(id: "g", faction: .germany, coord: HexCoord(q: 2, r: 1))
            ]
        )

        let result = RuleEngine().execute(.attack(attackerId: "missing", targetId: "g"), in: state)

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.validation.errors, [.divisionNotFound])
        XCTAssertEqual(result.state, state)
    }

    private static func division(
        id: String,
        faction: Faction,
        coord: HexCoord,
        hp: Int = 10,
        supplyState: SupplyState = .supplied,
        hasActed: Bool = false,
        retreatMode: RetreatMode = .retreatable
    ) -> Division {
        Division(
            id: id,
            name: id,
            faction: faction,
            coord: coord,
            facing: faction == .germany ? .west : .east,
            hp: hp,
            maxHP: 10,
            components: [
                DivisionComponent(type: .infantry, weight: 1.0)
            ],
            supplyState: supplyState,
            hasActed: hasActed,
            retreatMode: retreatMode
        )
    }

    private static func testState(
        activeFaction: Faction,
        divisions: [Division]
    ) -> GameState {
        testState(activeFaction: activeFaction, map: basicMap(width: 5, height: 5), divisions: divisions)
    }

    private static func testState(
        activeFaction: Faction,
        map: MapState,
        divisions: [Division]
    ) -> GameState {
        testState(
            activeFaction: activeFaction,
            map: map,
            diplomacyState: .empty,
            divisions: divisions
        )
    }

    private static func testState(
        activeFaction: Faction,
        map: MapState,
        diplomacyState: DiplomacyState,
        divisions: [Division]
    ) -> GameState {
        GameState(
            scenarioId: "test",
            turn: 1,
            maxTurns: 8,
            activeFaction: activeFaction,
            phase: activeFaction == .germany ? .germanAI : .alliedPlayer,
            map: map,
            diplomacyState: diplomacyState,
            divisions: divisions,
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: []
        )
    }

    private static func diplomaticPlayTestState() -> GameState {
        GameState(
            scenarioId: "diplomatic_play_test",
            turn: 1,
            maxTurns: 8,
            activeFaction: .britain,
            phase: .humanAction,
            turnOrder: [.britain, .austria],
            humanControlledFactions: [.britain],
            map: basicMap(width: 4, height: 4, supplySources: []),
            diplomacyState: DiplomacyState.initial(for: [.britain, .austria], turn: 1),
            divisions: [],
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: []
        )
    }

    private static func basicMap(
        width: Int,
        height: Int,
        supplySources: [SupplySource]? = nil
    ) -> MapState {
        var tiles: [HexCoord: HexTile] = [:]
        for q in 0..<width {
            for r in 0..<height {
                let coord = HexCoord(q: q, r: r)
                tiles[coord] = HexTile(coord: coord)
            }
        }

        return MapState(
            width: width,
            height: height,
            tiles: tiles,
            supplySources: supplySources ?? [
                SupplySource(id: "allied_supply", faction: .allies, coord: HexCoord(q: 0, r: 0)),
                SupplySource(id: "german_supply", faction: .germany, coord: HexCoord(q: width - 1, r: height - 1))
            ],
            objectives: []
        )
    }
}
