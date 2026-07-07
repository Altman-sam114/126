import Foundation

struct RulerDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: RulerDecisionRecord
}

struct RulerAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let countryId: CountryId?
    let aggression: Int
    let coalitionDiscipline: Int
    let riskTolerance: Int

    init(
        id: String,
        name: String,
        faction: Faction,
        countryId: CountryId?,
        aggression: Int,
        coalitionDiscipline: Int,
        riskTolerance: Int
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.countryId = countryId
        self.aggression = max(0, min(100, aggression))
        self.coalitionDiscipline = max(0, min(100, coalitionDiscipline))
        self.riskTolerance = max(0, min(100, riskTolerance))
    }
}

struct RulerAgent {
    let config: RulerAgentConfig

    func adjust(envelope: DirectiveEnvelope, in state: GameState) -> RulerDirectiveAdjustment {
        let snapshot = RulerStrategicSnapshot(faction: config.faction, state: state)
        let posture = choosePosture(snapshot: snapshot)
        let directives = envelope.directives.map { adjust(directive: $0, posture: posture, snapshot: snapshot) }
        let preferredZoneId = choosePreferredZoneId(snapshot: snapshot)
        let targetRegionIds = chooseTargetRegionIds(directives: directives, snapshot: snapshot)
        let record = RulerDecisionRecord(
            id: "ruler_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            countryId: config.countryId,
            rulerAgentId: config.id,
            posture: posture,
            preferredFrontZoneId: preferredZoneId,
            targetRegionIds: targetRegionIds,
            attackThresholdAdjustment: thresholdAdjustment(for: posture),
            reserveBias: reserveBias(for: posture),
            diplomacySummary: state.diplomacyState.summary(for: config.faction),
            rationale: rationale(for: posture, snapshot: snapshot)
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendRulerContext(envelope.theaterContext, record: record)
        )
        return RulerDirectiveAdjustment(envelope: adjustedEnvelope, record: record)
    }

    func diplomaticPlayResponses(in state: GameState) -> [DiplomaticPlayStanceRecord] {
        guard state.activeFaction == config.faction,
              state.phase.isActionPhase else {
            return []
        }

        return state.diplomacyState.activeDiplomaticPlays.compactMap { play in
            diplomaticPlayResponse(for: play, in: state)
        }
    }

    private func diplomaticPlayResponse(
        for play: DiplomaticPlay,
        in state: GameState
    ) -> DiplomaticPlayStanceRecord? {
        let stance = chooseDiplomaticPlayStance(for: play, in: state)
        guard state.diplomacyState.canRespondToDiplomaticPlay(
            actingFaction: config.faction,
            playId: play.id,
            stance: stance
        ) else {
            return nil
        }

        return DiplomaticPlayStanceRecord(
            playId: play.id,
            turn: state.turn,
            faction: config.faction,
            countryId: config.countryId ?? state.diplomacyState.primaryCountry(for: config.faction)?.id,
            agentId: config.id,
            stance: stance,
            rationale: diplomaticPlayRationale(stance: stance, play: play, in: state)
        )
    }

    private func chooseDiplomaticPlayStance(
        for play: DiplomaticPlay,
        in state: GameState
    ) -> DiplomaticPlayAIStance {
        let issuerCanBeSupported = state.diplomacyState.canSupportDiplomaticPlay(
            actingFaction: config.faction,
            playId: play.id,
            side: .issuer
        )
        let targetCanBeSupported = state.diplomacyState.canSupportDiplomaticPlay(
            actingFaction: config.faction,
            playId: play.id,
            side: .target
        )
        let issuerScore = issuerCanBeSupported ? diplomaticSupportScore(for: .issuer, in: play, state: state) : Int.min
        let targetScore = targetCanBeSupported ? diplomaticSupportScore(for: .target, in: play, state: state) : Int.min

        if issuerScore >= max(2, targetScore + 1) {
            return .supportIssuer
        }
        if targetScore >= max(2, issuerScore + 1) {
            return .supportTarget
        }
        return .neutral
    }

    private func diplomaticSupportScore(
        for side: DiplomaticPlaySupportSide,
        in play: DiplomaticPlay,
        state: GameState
    ) -> Int {
        let sideFaction = side == .issuer ? play.issuerFaction : play.targetFaction
        let opposingFaction = side == .issuer ? play.targetFaction : play.issuerFaction
        let relationToSide = state.diplomacyState.relationStatus(between: config.faction, and: sideFaction)
        let relationToOpposing = state.diplomacyState.relationStatus(between: config.faction, and: opposingFaction)
        var score = relationshipScore(relationToSide)

        switch relationToOpposing {
        case .atWar:
            score += 4
        case .hostile, .blockaded:
            score += 2
        case .truce:
            score += 1
        case .allied, .coBelligerent, .militaryAccess:
            score -= 2
        case .neutral:
            break
        }

        if config.coalitionDiscipline >= 60 && relationToSide == .coBelligerent {
            score += 1
        }
        if config.riskTolerance < 35 && play.escalation >= 70 {
            score -= 1
        }
        return score
    }

    private func relationshipScore(_ status: DiplomaticStatus) -> Int {
        switch status {
        case .allied:
            return 4
        case .coBelligerent:
            return 3
        case .militaryAccess:
            return 2
        case .truce:
            return 1
        case .neutral:
            return 0
        case .hostile, .blockaded:
            return -2
        case .atWar:
            return -100
        }
    }

    private func diplomaticPlayRationale(
        stance: DiplomaticPlayAIStance,
        play: DiplomaticPlay,
        in state: GameState
    ) -> String {
        let issuerStatus = state.diplomacyState.relationStatus(between: config.faction, and: play.issuerFaction).displayName
        let targetStatus = state.diplomacyState.relationStatus(between: config.faction, and: play.targetFaction).displayName
        switch stance {
        case .supportIssuer:
            return "Cabinet favors \(play.issuerFaction.displayName): issuer relation \(issuerStatus), target relation \(targetStatus)."
        case .supportTarget:
            return "Cabinet favors \(play.targetFaction.displayName): target relation \(targetStatus), issuer relation \(issuerStatus)."
        case .neutral:
            return "Cabinet remains neutral: issuer relation \(issuerStatus), target relation \(targetStatus)."
        }
    }

    private func choosePosture(snapshot: RulerStrategicSnapshot) -> RulerStrategicPosture {
        if snapshot.hostileCountryCount > 1 && config.coalitionDiscipline >= 55 {
            return .coalitionMaintenance
        }

        if snapshot.averageZonePressure >= 4 || snapshot.outnumberedFrontZoneCount > snapshot.advantagedFrontZoneCount {
            return .defensive
        }

        if snapshot.staticDefenseStreak >= 2 || snapshot.contestedFriendlyPresenceCount > 0 {
            return .stabilizeFront
        }

        let aggressionScore = config.aggression + config.riskTolerance / 2 + snapshot.advantagedFrontZoneCount * 8
        if aggressionScore >= 95 && snapshot.frontZoneCount > 0 {
            return .offensive
        }

        return snapshot.frontZoneCount > 1 ? .coalitionMaintenance : .stabilizeFront
    }

    private func adjust(
        directive: ZoneDirective,
        posture: RulerStrategicPosture,
        snapshot: RulerStrategicSnapshot
    ) -> ZoneDirective {
        switch (posture, directive.parameters) {
        case (.offensive, .attack(let attack)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: prioritizedRegions(attack.weightedRegions, snapshot: snapshot),
                    intensity: .allOut
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.defensive, .attack):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: 2, stance: .holdLine),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: .theater(TheaterId(directive.zoneId.rawValue))
            )
        case (.coalitionMaintenance, .defend(let defense)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: max(2, defense.targetReserves), stance: defense.stance),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .attack(let attack)) where attack.intensity == .allOut:
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: attack.weightedRegions,
                    intensity: .limitedCounter
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .defend):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: 1, stance: .flexible),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: directive.commandTarget
            )
        default:
            return directive
        }
    }

    private func choosePreferredZoneId(snapshot: RulerStrategicSnapshot) -> FrontZoneId? {
        snapshot.zoneScores.sorted {
            if $0.value == $1.value {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.value > $1.value
        }.first?.key
    }

    private func chooseTargetRegionIds(directives: [ZoneDirective], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        let directed = directives.flatMap(\.targetRegionIds)
        if !directed.isEmpty {
            return stableUnique(directed).prefix(4).map { $0 }
        }
        return snapshot.contestedRegionIds.prefix(4).map { $0 }
    }

    private func prioritizedRegions(_ regions: [RegionId], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        stableUnique(regions).sorted {
            let lhs = snapshot.regionPriority[$0, default: 0]
            let rhs = snapshot.regionPriority[$1, default: 0]
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    private func thresholdAdjustment(for posture: RulerStrategicPosture) -> Double {
        switch posture {
        case .offensive:
            return -0.15
        case .defensive:
            return 0.20
        case .coalitionMaintenance:
            return 0.05
        case .stabilizeFront:
            return 0.10
        }
    }

    private func reserveBias(for posture: RulerStrategicPosture) -> Int {
        switch posture {
        case .offensive:
            return 0
        case .defensive:
            return 2
        case .coalitionMaintenance:
            return 2
        case .stabilizeFront:
            return 1
        }
    }

    private func rationale(for posture: RulerStrategicPosture, snapshot: RulerStrategicSnapshot) -> String {
        switch posture {
        case .offensive:
            return "Cabinet sees \(snapshot.advantagedFrontZoneCount) advantaged command sector(s) and accepts offensive risk."
        case .defensive:
            return "Cabinet sees pressure \(snapshot.averageZonePressure) and \(snapshot.outnumberedFrontZoneCount) outnumbered command sector(s)."
        case .coalitionMaintenance:
            return "Cabinet preserves coalition reserves across \(snapshot.frontZoneCount) active command sector(s)."
        case .stabilizeFront:
            return "Cabinet avoids overextension while contested forward presence is resolved."
        }
    }

    private func appendRulerContext(_ context: String?, record: RulerDecisionRecord) -> String {
        let rulerContext = "Cabinet \(record.rulerAgentId): \(record.posture.displayName), target \(record.preferredFrontZoneId?.rawValue ?? "none")."
        guard let context, !context.isEmpty else {
            return rulerContext
        }
        return "\(context) \(rulerContext)"
    }

    private func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

struct RulerStrategicSnapshot {
    let frontZoneCount: Int
    let averageZonePressure: Int
    let advantagedFrontZoneCount: Int
    let outnumberedFrontZoneCount: Int
    let contestedFriendlyPresenceCount: Int
    let hostileCountryCount: Int
    let staticDefenseStreak: Int
    let contestedRegionIds: [RegionId]
    let regionPriority: [RegionId: Int]
    let zoneScores: [FrontZoneId: Int]

    init(faction: Faction, state: GameState) {
        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == faction && !$0.frontSegments.isEmpty }
        frontZoneCount = zones.count
        averageZonePressure = zones.isEmpty ? 0 : zones.reduce(0) { $0 + $1.pressure } / zones.count
        hostileCountryCount = state.diplomacyState.hostileCountryIds(to: faction).count

        var advantaged = 0
        var outnumbered = 0
        var contestedPresence = 0
        var contestedRegions: [RegionId] = []
        var priorities: [RegionId: Int] = [:]
        var scores: [FrontZoneId: Int] = [:]

        for zone in zones {
            let friendlyStrength = Self.strength(for: zone.unitsFront + zone.unitsDepth, faction: faction, state: state)
            let enemyStrength = Self.enemyStrength(adjacentTo: zone, state: state)
            if friendlyStrength >= enemyStrength + 2 {
                advantaged += 1
            } else if enemyStrength > friendlyStrength {
                outnumbered += 1
            }

            let zoneScore = max(0, friendlyStrength - enemyStrength) + zone.pressure + zone.frontSegments.count
            scores[zone.id] = zoneScore

            for segment in zone.frontSegments {
                contestedRegions.append(segment.regionId)
                priorities[segment.regionId, default: 0] += zoneScore + segment.strength
                if segment.isEncircled {
                    priorities[segment.regionId, default: 0] += 6
                }
                if let controller = state.map.regions[segment.regionId]?.controller,
                   state.diplomacyState.canAttack(attacker: faction, target: controller) {
                    contestedPresence += 1
                    priorities[segment.regionId, default: 0] += 4
                }
            }
        }

        advantagedFrontZoneCount = advantaged
        outnumberedFrontZoneCount = outnumbered
        contestedFriendlyPresenceCount = contestedPresence
        contestedRegionIds = Self.stableUnique(contestedRegions).sorted { $0.rawValue < $1.rawValue }
        regionPriority = priorities
        zoneScores = scores
        staticDefenseStreak = Self.staticDefenseStreak(for: faction, records: state.warDirectiveRecords)
    }

    private static func strength(for unitIds: [String], faction: Faction, state: GameState) -> Int {
        let ids = Set(unitIds)
        return state.divisions
            .filter { ids.contains($0.id) && $0.faction == faction && !$0.isDestroyed }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.attack) }
    }

    private static func enemyStrength(adjacentTo zone: FrontZone, state: GameState) -> Int {
        let visibleEnemyRegions = Set(zone.frontSegments.map(\.regionId))
        return state.divisions
            .filter { state.diplomacyState.canAttack(attacker: zone.faction, target: $0.faction) && !$0.isDestroyed }
            .filter { division in
                guard let regionId = division.location(in: state.map) else {
                    return false
                }
                return visibleEnemyRegions.contains(regionId)
            }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.defense) }
    }

    private static func staticDefenseStreak(for faction: Faction, records: [WarDirectiveRecord]) -> Int {
        var streak = 0
        for record in records.reversed() where record.faction == faction {
            if record.directiveType == .defend {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

extension RulerAgent {
    static func automatic(for faction: Faction, in state: GameState) -> RulerAgent {
        let country = state.diplomacyState.primaryCountry(for: faction)
        let config: RulerAgentConfig
        switch faction {
        case .germany:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_germany",
                name: "German Ruler",
                faction: faction,
                countryId: country?.id,
                aggression: 82,
                coalitionDiscipline: 45,
                riskTolerance: 68
            )
        case .allies:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_allies",
                name: "Allied Supreme Council",
                faction: faction,
                countryId: country?.id,
                aggression: 58,
                coalitionDiscipline: 82,
                riskTolerance: 48
            )
        default:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_\(faction.rawValue)",
                name: "\(faction.displayName) Cabinet",
                faction: faction,
                countryId: country?.id,
                aggression: faction.isNeutral ? 20 : 55,
                coalitionDiscipline: faction.isNeutral ? 60 : 65,
                riskTolerance: faction.isNeutral ? 20 : 45
            )
        }
        return RulerAgent(config: config)
    }
}
