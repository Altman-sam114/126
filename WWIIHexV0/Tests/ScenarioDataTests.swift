import XCTest
@testable import WWIIHexV0

final class ScenarioDataTests: XCTestCase {
    func testArdennesDataSetDecodesAndValidates() throws {
        let loader = DataLoader()

        XCTAssertNoThrow(try loader.loadScenarioDefinition())
        XCTAssertNoThrow(try loader.loadTerrainRules())
        XCTAssertNoThrow(try loader.loadUnitTemplates())
        XCTAssertNoThrow(try loader.loadGeneralAgents())
        XCTAssertNoThrow(try loader.loadArdennesDataSet())
    }

    func testArdennesMapHasExpectedShapeAndUniqueCoordinates() throws {
        let dataSet = try DataLoader().loadArdennesDataSet()
        let scenario = dataSet.scenario
        let coords = scenario.map.tiles.map(\.coord)

        XCTAssertEqual(scenario.id, "mapeditor_scenario")
        XCTAssertEqual(scenario.displayName, "MapEditor Scenario")
        XCTAssertEqual(scenario.map.width, 15)
        XCTAssertEqual(scenario.map.height, 9)
        XCTAssertTrue(scenario.map.isSparse)
        XCTAssertFalse(scenario.map.tiles.isEmpty)
        XCTAssertLessThan(scenario.map.tiles.count, scenario.map.width * scenario.map.height)
        XCTAssertEqual(Set(coords).count, coords.count)
        XCTAssertEqual(scenario.maxTurns, 12)
        XCTAssertEqual(scenario.initialTurn, 1)
        XCTAssertEqual(scenario.initialPhase, GamePhase.alliedPlayer.rawValue)
        XCTAssertEqual(scenario.playerFaction, "allies")
        XCTAssertEqual(scenario.aiFaction, "germany")
    }

    func testInitialUnitsAreUniquePlacedAndTemplateBacked() throws {
        let dataSet = try DataLoader().loadArdennesDataSet()
        let scenario = dataSet.scenario
        let unitIds = scenario.initialUnits.map(\.id)
        let unitCoords = scenario.initialUnits.map(\.coord)
        let tileCoords = Set(scenario.map.tiles.map(\.coord))
        let templateIds = Set(dataSet.unitTemplates.map(\.id))

        XCTAssertEqual(unitIds.count, 41)
        XCTAssertEqual(Set(unitIds).count, unitIds.count)
        XCTAssertEqual(Set(unitCoords).count, unitCoords.count)
        XCTAssertTrue(scenario.initialUnits.allSatisfy { tileCoords.contains($0.coord) })
        XCTAssertTrue(scenario.initialUnits.allSatisfy { templateIds.contains($0.templateId) })

        let germanUnits = scenario.initialUnits.filter { $0.faction == "germany" }
        let alliedUnits = scenario.initialUnits.filter { $0.faction == "allies" }
        XCTAssertEqual(germanUnits.count, 20)
        XCTAssertEqual(alliedUnits.count, 21)
        XCTAssertTrue(scenario.initialUnits.allSatisfy { $0.assignedAgentId == nil })
    }

    func testTemplateComponentWeightsSumToOne() throws {
        let dataSet = try DataLoader().loadArdennesDataSet()
        let expectedTemplateIds = Set([
            "panzer_division",
            "motorized_division",
            "infantry_division",
            "artillery_division",
            "anti_tank_division",
            "garrison_division"
        ])

        XCTAssertEqual(Set(dataSet.unitTemplates.map(\.id)), expectedTemplateIds)

        for template in dataSet.unitTemplates {
            let totalWeight = template.components.reduce(0.0) { $0 + $1.weight }
            XCTAssertEqual(totalWeight, 1.0, accuracy: 0.0001, "Invalid component weights for \(template.id)")
        }
    }

    func testSupplySourcesObjectivesAndVictoryReferencesAreValid() throws {
        let dataSet = try DataLoader().loadArdennesDataSet()
        let scenario = dataSet.scenario
        let objectiveIds = scenario.objectives.map(\.id)
        let objectiveIdSet = Set(objectiveIds)

        let supplyTiles = scenario.map.tiles.filter(\.isSupplySource)
        XCTAssertFalse(supplyTiles.isEmpty, "Missing supply source.")
        XCTAssertTrue(supplyTiles.allSatisfy { !$0.controller.isEmpty }, "Supply sources should have a hex controller.")
        XCTAssertEqual(Set(objectiveIds).count, objectiveIds.count)

        for condition in scenario.victoryConditions {
            if let objectiveId = condition.objectiveId {
                XCTAssertTrue(objectiveIdSet.contains(objectiveId), "\(condition.id) references unknown objective.")
            }

            for objectiveId in condition.objectiveIds ?? [] {
                XCTAssertTrue(objectiveIdSet.contains(objectiveId), "\(condition.id) references unknown objective.")
            }
        }
    }

    func testGeneralAgentCatalogLoadsButMapEditorScenarioDoesNotRequireLegacyAssignments() throws {
        let dataSet = try DataLoader().loadArdennesDataSet()
        let guderian = try XCTUnwrap(dataSet.generalAgents.first { $0.id == "guderian" })

        XCTAssertEqual(guderian.name, "Heinz Guderian")
        XCTAssertEqual(guderian.faction, "germany")
        XCTAssertEqual(guderian.role, "armyCommander")
        XCTAssertEqual(guderian.commandStyle, "breakthrough")
        XCTAssertEqual(dataSet.scenario.id, "mapeditor_scenario")
        XCTAssertTrue(dataSet.scenario.initialUnits.allSatisfy { $0.assignedAgentId == nil })
    }

    func testVictorianPersonasMapToRuntimeAgents() throws {
        let loader = DataLoader()
        let state = loader.loadInitialGameState()

        let russianCommander = GameAgent.defaultCommander(for: .russia, from: loader, state: state)
        XCTAssertEqual(russianCommander.id, "menshikov")
        XCTAssertEqual(russianCommander.faction, .russia)
        XCTAssertEqual(russianCommander.role, .fieldCommander)
        XCTAssertEqual(russianCommander.personality.traits, ["cautious"])

        let britishCommander = GameAgent.defaultCommander(for: .britain, from: loader, state: state)
        XCTAssertEqual(britishCommander.id, "raglan")
        XCTAssertEqual(britishCommander.faction, .britain)
        XCTAssertEqual(britishCommander.role, .expeditionaryCommander)
    }

    func testVictorianMarshalDirectiveUsesRuntimePersonaIdentity() async throws {
        let loader = DataLoader()
        var state = loader.loadInitialGameState()
        state.activeFaction = .russia
        state.phase = .aiAction

        let commander = GameAgent.defaultCommander(for: .russia, from: loader, state: state)
        let manager = TurnManager(
            agent: commander,
            provider: MockAIClient(),
            providerName: "Simulated Staff",
            commandHandler: RuleEngine(),
            commanderPool: TheaterCommanderPool.automatic(for: state),
            marshalAgent: MarshalAgent(config: MarshalAgentConfig.fromCommander(commander, state: state)),
            rulerAgent: RulerAgent.automatic(for: .russia, in: state)
        )

        let outcome = await manager.runAITurn(state: state, faction: .russia)

        XCTAssertEqual(commander.id, "menshikov")
        XCTAssertEqual(outcome.record.agentId, "menshikov")
        XCTAssertEqual(outcome.record.provider, "Simulated Staff+Cabinet+MarshalDirective")
        XCTAssertTrue(outcome.record.parsedIntent?.contains("Cabinet") == true)
        XCTAssertTrue(outcome.record.rawJSON?.contains("Cabinet Directive JSON") == true)
        XCTAssertFalse(outcome.directiveRecords.isEmpty)
        XCTAssertTrue(outcome.directiveRecords.allSatisfy { $0.issuerId == "menshikov" })
        XCTAssertTrue(outcome.directiveRecords.allSatisfy { $0.commanderAgentId == "menshikov" })
        XCTAssertEqual(outcome.state.diplomacyState.latestRulerRecord?.faction, .russia)
        XCTAssertFalse(outcome.record.rawJSON?.contains("marshal_russia") == true)
    }
}
