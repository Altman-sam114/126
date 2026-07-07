import Foundation

struct CountryId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiplomaticBlocId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DiplomaticStatus: String, Codable, Equatable, CaseIterable {
    case allied
    case coBelligerent
    case neutral
    case hostile
    case atWar
    case truce
    case militaryAccess
    case blockaded

    var isHostile: Bool {
        self == .hostile || self == .atWar || self == .blockaded
    }

    var allowsAttack: Bool {
        self == .atWar
    }

    var allowsTerritoryEntry: Bool {
        switch self {
        case .allied, .coBelligerent, .militaryAccess:
            return true
        case .neutral, .hostile, .atWar, .truce, .blockaded:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .allied:
            return "Allied"
        case .coBelligerent:
            return "Co-belligerent"
        case .neutral:
            return "Neutral"
        case .hostile:
            return "Hostile"
        case .atWar:
            return "At war"
        case .truce:
            return "Truce"
        case .militaryAccess:
            return "Military access"
        case .blockaded:
            return "Blockaded"
        }
    }
}

struct CountryProfile: Identifiable, Codable, Equatable {
    let id: CountryId
    var name: String
    var faction: Faction
    var blocId: DiplomaticBlocId
    var rulerAgentId: String
    var isPrimaryBelligerent: Bool
    var capitalRegionId: RegionId?
    var surrenderProgress: Int
    var warSupport: Int

    init(
        id: CountryId,
        name: String,
        faction: Faction,
        blocId: DiplomaticBlocId,
        rulerAgentId: String,
        isPrimaryBelligerent: Bool = false,
        capitalRegionId: RegionId? = nil,
        surrenderProgress: Int = 0,
        warSupport: Int = 70
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.blocId = blocId
        self.rulerAgentId = rulerAgentId
        self.isPrimaryBelligerent = isPrimaryBelligerent
        self.capitalRegionId = capitalRegionId
        self.surrenderProgress = max(0, min(100, surrenderProgress))
        self.warSupport = max(0, min(100, warSupport))
    }
}

struct DiplomaticBloc: Identifiable, Codable, Equatable {
    let id: DiplomaticBlocId
    var name: String
    var faction: Faction
    var memberCountryIds: [CountryId]

    init(id: DiplomaticBlocId, name: String, faction: Faction, memberCountryIds: [CountryId]) {
        self.id = id
        self.name = name
        self.faction = faction
        self.memberCountryIds = memberCountryIds.sorted { $0.rawValue < $1.rawValue }
    }
}

struct DiplomaticRelation: Identifiable, Codable, Equatable {
    let firstCountryId: CountryId
    let secondCountryId: CountryId
    var status: DiplomaticStatus
    var tension: Int
    var sinceTurn: Int

    var id: String {
        "\(firstCountryId.rawValue):\(secondCountryId.rawValue)"
    }

    init(
        firstCountryId: CountryId,
        secondCountryId: CountryId,
        status: DiplomaticStatus,
        tension: Int = 0,
        sinceTurn: Int = 1
    ) {
        if firstCountryId.rawValue <= secondCountryId.rawValue {
            self.firstCountryId = firstCountryId
            self.secondCountryId = secondCountryId
        } else {
            self.firstCountryId = secondCountryId
            self.secondCountryId = firstCountryId
        }
        self.status = status
        self.tension = max(0, min(100, tension))
        self.sinceTurn = max(1, sinceTurn)
    }

    func contains(_ countryId: CountryId) -> Bool {
        firstCountryId == countryId || secondCountryId == countryId
    }
}

enum RulerStrategicPosture: String, Codable, Equatable, CaseIterable {
    case offensive
    case defensive
    case coalitionMaintenance
    case stabilizeFront

    var displayName: String {
        switch self {
        case .offensive:
            return "Offensive"
        case .defensive:
            return "Defensive"
        case .coalitionMaintenance:
            return "Coalition"
        case .stabilizeFront:
            return "Stabilize"
        }
    }
}

struct RulerDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let rulerAgentId: String
    let posture: RulerStrategicPosture
    let preferredFrontZoneId: FrontZoneId?
    let targetRegionIds: [RegionId]
    let attackThresholdAdjustment: Double
    let reserveBias: Int
    let diplomacySummary: String
    let rationale: String
}

struct WarSupportAdjustment: Equatable {
    let countryId: CountryId
    let countryName: String
    let oldValue: Int
    let newValue: Int
}

enum DiplomaticPlayAIStance: String, Codable, Equatable, CaseIterable {
    case supportIssuer
    case supportTarget
    case neutral

    var displayName: String {
        switch self {
        case .supportIssuer:
            return "Support issuer"
        case .supportTarget:
            return "Support target"
        case .neutral:
            return "Neutral"
        }
    }

    var supportSide: DiplomaticPlaySupportSide? {
        switch self {
        case .supportIssuer:
            return .issuer
        case .supportTarget:
            return .target
        case .neutral:
            return nil
        }
    }
}

struct DiplomaticPlayStanceRecord: Identifiable, Codable, Equatable {
    let id: String
    let playId: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let agentId: String
    let stance: DiplomaticPlayAIStance
    let rationale: String
    let didIssueSupportCommand: Bool
    let commandSucceeded: Bool?
    let validationErrors: [String]

    init(
        id: String? = nil,
        playId: String,
        turn: Int,
        faction: Faction,
        countryId: CountryId?,
        agentId: String,
        stance: DiplomaticPlayAIStance,
        rationale: String,
        didIssueSupportCommand: Bool = false,
        commandSucceeded: Bool? = nil,
        validationErrors: [String] = []
    ) {
        self.id = id ?? "ai_stance_\(playId)_turn_\(turn)_\(faction.rawValue)_\(agentId)_\(stance.rawValue)"
        self.playId = playId
        self.turn = max(1, turn)
        self.faction = faction
        self.countryId = countryId
        self.agentId = agentId
        self.stance = stance
        self.rationale = rationale
        self.didIssueSupportCommand = didIssueSupportCommand
        self.commandSucceeded = commandSucceeded
        self.validationErrors = validationErrors
    }

    func resolvingSupportCommand(succeeded: Bool, validationErrors: [String]) -> DiplomaticPlayStanceRecord {
        DiplomaticPlayStanceRecord(
            id: id,
            playId: playId,
            turn: turn,
            faction: faction,
            countryId: countryId,
            agentId: agentId,
            stance: stance,
            rationale: rationale,
            didIssueSupportCommand: true,
            commandSucceeded: succeeded,
            validationErrors: validationErrors
        )
    }
}

enum DiplomaticPlayWarGoal: String, Codable, Equatable, CaseIterable {
    case protectOttomanTerritory
    case demandDanubianWithdrawal
    case controlBlackSeaPort
    case keepStraitsOpen
    case weakenPrestige

    var displayName: String {
        switch self {
        case .protectOttomanTerritory:
            return "Protect Ottoman territory"
        case .demandDanubianWithdrawal:
            return "Demand Danubian withdrawal"
        case .controlBlackSeaPort:
            return "Control Black Sea port"
        case .keepStraitsOpen:
            return "Keep Straits open"
        case .weakenPrestige:
            return "Weaken prestige"
        }
    }

    var dynamicVictoryObjectiveIds: [String] {
        Array(Set(dynamicVictoryObjectiveGroups.flatMap { $0 })).sorted()
    }

    var warSupportVictoryThreshold: Int? {
        switch self {
        case .weakenPrestige:
            return 35
        case .protectOttomanTerritory, .demandDanubianWithdrawal, .controlBlackSeaPort, .keepStraitsOpen:
            return nil
        }
    }

    var dynamicVictoryObjectiveGroups: [[String]] {
        switch self {
        case .protectOttomanTerritory:
            return [["obj_constantinople", "obj_silistra"]]
        case .demandDanubianWithdrawal:
            return [["obj_silistra", "obj_danube_mouth"]]
        case .controlBlackSeaPort:
            return [["obj_sevastopol"], ["obj_odessa"]]
        case .keepStraitsOpen:
            return [["obj_constantinople"]]
        case .weakenPrestige:
            return []
        }
    }
}

enum DiplomaticPlayOutcome: String, Codable, Equatable {
    case active
    case backedDown
    case negotiatedSettlement
    case escalatedToWar
    case truceSettlement

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .backedDown:
            return "Backed down"
        case .negotiatedSettlement:
            return "Negotiated"
        case .escalatedToWar:
            return "Escalated to war"
        case .truceSettlement:
            return "Truce"
        }
    }
}

struct DiplomaticPlaySettlementRecord: Identifiable, Codable, Equatable {
    let id: String
    let playId: String
    let turn: Int
    let concedingFaction: Faction
    let beneficiaryFaction: Faction
    let warGoal: DiplomaticPlayWarGoal
    let summary: String
    let concedingWarSupportDelta: Int
    let beneficiaryWarSupportDelta: Int

    init(
        id: String? = nil,
        playId: String,
        turn: Int,
        concedingFaction: Faction,
        beneficiaryFaction: Faction,
        warGoal: DiplomaticPlayWarGoal,
        summary: String,
        concedingWarSupportDelta: Int,
        beneficiaryWarSupportDelta: Int
    ) {
        self.id = id ?? "settlement_\(playId)_turn_\(max(1, turn))_\(concedingFaction.rawValue)"
        self.playId = playId
        self.turn = max(1, turn)
        self.concedingFaction = concedingFaction
        self.beneficiaryFaction = beneficiaryFaction
        self.warGoal = warGoal
        self.summary = summary
        self.concedingWarSupportDelta = concedingWarSupportDelta
        self.beneficiaryWarSupportDelta = beneficiaryWarSupportDelta
    }
}

struct DiplomaticPlay: Identifiable, Codable, Equatable {
    let id: String
    let issuerFaction: Faction
    let targetFaction: Faction
    let regionId: RegionId?
    let warGoal: DiplomaticPlayWarGoal
    var escalation: Int
    var backers: [Faction]
    var opposingBackers: [Faction]
    let createdTurn: Int
    let deadlineTurn: Int
    var outcome: DiplomaticPlayOutcome
    var aiStanceRecords: [DiplomaticPlayStanceRecord]
    var settlementRecord: DiplomaticPlaySettlementRecord?

    init(
        id: String,
        issuerFaction: Faction,
        targetFaction: Faction,
        regionId: RegionId?,
        warGoal: DiplomaticPlayWarGoal,
        escalation: Int = 20,
        backers: [Faction],
        opposingBackers: [Faction],
        createdTurn: Int,
        deadlineTurn: Int,
        outcome: DiplomaticPlayOutcome = .active,
        aiStanceRecords: [DiplomaticPlayStanceRecord] = [],
        settlementRecord: DiplomaticPlaySettlementRecord? = nil
    ) {
        self.id = id
        self.issuerFaction = issuerFaction
        self.targetFaction = targetFaction
        self.regionId = regionId
        self.warGoal = warGoal
        self.escalation = max(0, min(100, escalation))
        self.backers = backers.sorted { $0.rawValue < $1.rawValue }
        self.opposingBackers = opposingBackers.sorted { $0.rawValue < $1.rawValue }
        self.createdTurn = max(1, createdTurn)
        self.deadlineTurn = max(self.createdTurn + 1, deadlineTurn)
        self.outcome = outcome
        self.aiStanceRecords = aiStanceRecords
        self.settlementRecord = settlementRecord
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case issuerFaction
        case targetFaction
        case regionId
        case warGoal
        case escalation
        case backers
        case opposingBackers
        case createdTurn
        case deadlineTurn
        case outcome
        case aiStanceRecords
        case settlementRecord
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            issuerFaction: try container.decode(Faction.self, forKey: .issuerFaction),
            targetFaction: try container.decode(Faction.self, forKey: .targetFaction),
            regionId: try container.decodeIfPresent(RegionId.self, forKey: .regionId),
            warGoal: try container.decode(DiplomaticPlayWarGoal.self, forKey: .warGoal),
            escalation: try container.decode(Int.self, forKey: .escalation),
            backers: try container.decode([Faction].self, forKey: .backers),
            opposingBackers: try container.decode([Faction].self, forKey: .opposingBackers),
            createdTurn: try container.decode(Int.self, forKey: .createdTurn),
            deadlineTurn: try container.decode(Int.self, forKey: .deadlineTurn),
            outcome: try container.decode(DiplomaticPlayOutcome.self, forKey: .outcome),
            aiStanceRecords: try container.decodeIfPresent([DiplomaticPlayStanceRecord].self, forKey: .aiStanceRecords) ?? [],
            settlementRecord: try container.decodeIfPresent(DiplomaticPlaySettlementRecord.self, forKey: .settlementRecord)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(issuerFaction, forKey: .issuerFaction)
        try container.encode(targetFaction, forKey: .targetFaction)
        try container.encodeIfPresent(regionId, forKey: .regionId)
        try container.encode(warGoal, forKey: .warGoal)
        try container.encode(escalation, forKey: .escalation)
        try container.encode(backers, forKey: .backers)
        try container.encode(opposingBackers, forKey: .opposingBackers)
        try container.encode(createdTurn, forKey: .createdTurn)
        try container.encode(deadlineTurn, forKey: .deadlineTurn)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(aiStanceRecords, forKey: .aiStanceRecords)
        try container.encodeIfPresent(settlementRecord, forKey: .settlementRecord)
    }
}

struct DiplomaticPlayAdvanceRecord: Equatable {
    let playId: String
    let issuerFaction: Faction
    let targetFaction: Faction
    let issuerSideFactions: [Faction]
    let targetSideFactions: [Faction]
    let warGoal: DiplomaticPlayWarGoal
    let escalation: Int
    let deadlineTurn: Int
    let outcome: DiplomaticPlayOutcome
    let didEscalateToWar: Bool
}

struct DiplomacyState: Codable, Equatable {
    static let defaultTruceDuration = 2

    var countries: [CountryProfile]
    var blocs: [DiplomaticBloc]
    var relations: [DiplomaticRelation]
    var rulerRecords: [RulerDecisionRecord]
    var diplomaticPlays: [DiplomaticPlay]
    var lastUpdatedTurn: Int?

    init(
        countries: [CountryProfile] = [],
        blocs: [DiplomaticBloc] = [],
        relations: [DiplomaticRelation] = [],
        rulerRecords: [RulerDecisionRecord] = [],
        diplomaticPlays: [DiplomaticPlay] = [],
        lastUpdatedTurn: Int? = nil
    ) {
        self.countries = countries.sorted { $0.id.rawValue < $1.id.rawValue }
        self.blocs = blocs.sorted { $0.id.rawValue < $1.id.rawValue }
        self.relations = relations.sorted { $0.id < $1.id }
        self.rulerRecords = rulerRecords
        self.diplomaticPlays = diplomaticPlays.sorted { $0.id < $1.id }
        self.lastUpdatedTurn = lastUpdatedTurn
    }

    private enum CodingKeys: String, CodingKey {
        case countries
        case blocs
        case relations
        case rulerRecords
        case diplomaticPlays
        case lastUpdatedTurn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            countries: try container.decodeIfPresent([CountryProfile].self, forKey: .countries) ?? [],
            blocs: try container.decodeIfPresent([DiplomaticBloc].self, forKey: .blocs) ?? [],
            relations: try container.decodeIfPresent([DiplomaticRelation].self, forKey: .relations) ?? [],
            rulerRecords: try container.decodeIfPresent([RulerDecisionRecord].self, forKey: .rulerRecords) ?? [],
            diplomaticPlays: try container.decodeIfPresent([DiplomaticPlay].self, forKey: .diplomaticPlays) ?? [],
            lastUpdatedTurn: try container.decodeIfPresent(Int.self, forKey: .lastUpdatedTurn)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(countries, forKey: .countries)
        try container.encode(blocs, forKey: .blocs)
        try container.encode(relations, forKey: .relations)
        try container.encode(rulerRecords, forKey: .rulerRecords)
        try container.encode(diplomaticPlays, forKey: .diplomaticPlays)
        try container.encodeIfPresent(lastUpdatedTurn, forKey: .lastUpdatedTurn)
    }

    static var empty: DiplomacyState {
        DiplomacyState()
    }

    static func initial(for factions: [Faction], scenarioId: String? = nil, turn: Int) -> DiplomacyState {
        var countries: [CountryProfile] = []
        var blocs: [DiplomaticBloc] = []

        if factions.contains(.germany) {
            countries.append(
                CountryProfile(
                    id: "germany",
                    name: "German Reich",
                    faction: .germany,
                    blocId: "axis",
                    rulerAgentId: "ruler_germany",
                    isPrimaryBelligerent: true,
                    warSupport: 82
                )
            )
            blocs.append(DiplomaticBloc(id: "axis", name: "Axis", faction: .germany, memberCountryIds: ["germany"]))
        }

        if factions.contains(.allies) {
            countries.append(
                CountryProfile(
                    id: "united_states",
                    name: "United States",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_allies",
                    isPrimaryBelligerent: true,
                    warSupport: 78
                )
            )
            countries.append(
                CountryProfile(
                    id: "united_kingdom",
                    name: "United Kingdom",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_uk",
                    warSupport: 74
                )
            )
            countries.append(
                CountryProfile(
                    id: "belgium",
                    name: "Belgium",
                    faction: .allies,
                    blocId: "allied_coalition",
                    rulerAgentId: "ruler_belgium",
                    warSupport: 68
                )
            )
            blocs.append(
                DiplomaticBloc(
                    id: "allied_coalition",
                    name: "Allied Coalition",
                    faction: .allies,
                    memberCountryIds: ["belgium", "united_kingdom", "united_states"]
                )
            )
        }

        appendVictorianCountryProfiles(for: factions, countries: &countries, blocs: &blocs)
        let relations = scenarioId == "black_sea_crisis_1853"
            ? makeBlackSeaCrisisRelations(countries: countries, turn: turn)
            : makeInitialRelations(countries: countries, turn: turn)

        return DiplomacyState(
            countries: countries,
            blocs: blocs,
            relations: relations,
            lastUpdatedTurn: turn
        )
    }

    static func initial(from factionStrings: [String], scenarioId: String? = nil, turn: Int) -> DiplomacyState {
        let factions = factionStrings.compactMap(Faction.init(rawValue:))
        return initial(for: factions.isEmpty ? Faction.legacyTurnOrder : factions, scenarioId: scenarioId, turn: turn)
    }

    var latestRulerRecord: RulerDecisionRecord? {
        rulerRecords.last
    }

    var activeDiplomaticPlays: [DiplomaticPlay] {
        diplomaticPlays
            .filter { $0.outcome == .active }
            .sorted { lhs, rhs in
                if lhs.deadlineTurn != rhs.deadlineTurn {
                    return lhs.deadlineTurn < rhs.deadlineTurn
                }
                return lhs.id < rhs.id
            }
    }

    func latestStanceRecord(for playId: String, faction: Faction) -> DiplomaticPlayStanceRecord? {
        diplomaticPlay(id: playId)?
            .aiStanceRecords
            .last(where: { $0.faction == faction })
    }

    func countries(for faction: Faction) -> [CountryProfile] {
        countries.filter { $0.faction == faction }
    }

    func primaryCountry(for faction: Faction) -> CountryProfile? {
        countries(for: faction).first(where: \.isPrimaryBelligerent) ?? countries(for: faction).first
    }

    func relation(between lhs: CountryId, and rhs: CountryId) -> DiplomaticRelation? {
        let key = DiplomaticRelation(firstCountryId: lhs, secondCountryId: rhs, status: .neutral).id
        return relations.first { $0.id == key }
    }

    func truceExpiresTurn(between lhs: Faction, and rhs: Faction) -> Int? {
        guard relationStatus(between: lhs, and: rhs) == .truce else {
            return nil
        }

        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        var expiryTurns: [Int] = []
        for lhsCountry in lhsCountries {
            for rhsCountry in rhsCountries {
                guard let relation = relation(between: lhsCountry.id, and: rhsCountry.id),
                      relation.status == .truce else {
                    continue
                }
                expiryTurns.append(relation.sinceTurn + Self.defaultTruceDuration)
            }
        }
        return expiryTurns.max()
    }

    func truceIsActive(between lhs: Faction, and rhs: Faction, turn: Int) -> Bool {
        guard let expiresTurn = truceExpiresTurn(between: lhs, and: rhs) else {
            return false
        }
        return turn <= expiresTurn
    }

    func diplomaticPlay(id: String) -> DiplomaticPlay? {
        diplomaticPlays.first { $0.id == id }
    }

    func canCreateDiplomaticPlay(
        issuerFaction: Faction,
        targetFaction: Faction,
        regionId: RegionId?,
        turn: Int? = nil
    ) -> Bool {
        guard issuerFaction != targetFaction,
              issuerFaction.participatesInTurnOrder,
              targetFaction.participatesInTurnOrder,
              !targetFaction.isNeutral else {
            return false
        }

        guard !countries(for: issuerFaction).isEmpty,
              !countries(for: targetFaction).isEmpty else {
            return false
        }

        let relation = relationStatus(between: issuerFaction, and: targetFaction)
        guard relation != .atWar else {
            return false
        }
        if relation == .truce {
            guard let turn,
                  !truceIsActive(between: issuerFaction, and: targetFaction, turn: turn) else {
                return false
            }
        }

        guard !activeDiplomaticPlays.contains(where: {
            Self.matchesDiplomaticPlay($0, lhs: issuerFaction, rhs: targetFaction, regionId: regionId)
        }) else {
            return false
        }

        guard let turn else {
            return true
        }

        return !diplomaticPlays.contains {
            guard $0.outcome == .negotiatedSettlement,
                  let settlement = $0.settlementRecord,
                  Self.matchesDiplomaticPlay($0, lhs: issuerFaction, rhs: targetFaction, regionId: regionId) else {
                return false
            }
            return turn <= settlement.turn
        }
    }

    @discardableResult
    mutating func createDiplomaticPlay(
        issuerFaction: Faction,
        targetFaction: Faction,
        regionId: RegionId?,
        warGoal: DiplomaticPlayWarGoal,
        turn: Int,
        duration: Int = 3
    ) -> DiplomaticPlay? {
        guard canCreateDiplomaticPlay(
            issuerFaction: issuerFaction,
            targetFaction: targetFaction,
            regionId: regionId,
            turn: turn
        ) else {
            return nil
        }

        let baseId = Self.diplomaticPlayId(
            issuerFaction: issuerFaction,
            targetFaction: targetFaction,
            regionId: regionId,
            warGoal: warGoal,
            turn: turn
        )
        let play = DiplomaticPlay(
            id: Self.uniqueDiplomaticPlayId(
                baseId: baseId,
                existingIds: Set(diplomaticPlays.map(\.id))
            ),
            issuerFaction: issuerFaction,
            targetFaction: targetFaction,
            regionId: regionId,
            warGoal: warGoal,
            backers: [issuerFaction],
            opposingBackers: [targetFaction],
            createdTurn: turn,
            deadlineTurn: turn + max(1, duration)
        )
        diplomaticPlays.append(play)
        diplomaticPlays.sort { $0.id < $1.id }
        lastUpdatedTurn = turn
        return play
    }

    func canOfferConcession(actingFaction: Faction, playId: String) -> Bool {
        guard actingFaction.participatesInTurnOrder,
              let play = diplomaticPlay(id: playId),
              play.outcome == .active,
              play.issuerFaction == actingFaction || play.targetFaction == actingFaction else {
            return false
        }

        return relationStatus(between: play.issuerFaction, and: play.targetFaction) != .atWar
    }

    @discardableResult
    mutating func offerConcession(playId: String, actingFaction: Faction, turn: Int) -> DiplomaticPlay? {
        guard canOfferConcession(actingFaction: actingFaction, playId: playId),
              let index = diplomaticPlays.firstIndex(where: { $0.id == playId }) else {
            return nil
        }

        let play = diplomaticPlays[index]
        let beneficiaryFaction = play.issuerFaction == actingFaction ? play.targetFaction : play.issuerFaction
        let concedingOldWarSupport = primaryCountry(for: actingFaction)?.warSupport
        let beneficiaryOldWarSupport = primaryCountry(for: beneficiaryFaction)?.warSupport
        _ = adjustWarSupport(for: actingFaction, delta: -4, turn: turn)
        _ = adjustWarSupport(for: beneficiaryFaction, delta: 2, turn: turn)
        let concedingWarSupportDelta = Self.warSupportDelta(
            from: concedingOldWarSupport,
            to: primaryCountry(for: actingFaction)?.warSupport
        )
        let beneficiaryWarSupportDelta = Self.warSupportDelta(
            from: beneficiaryOldWarSupport,
            to: primaryCountry(for: beneficiaryFaction)?.warSupport
        )
        diplomaticPlays[index].settlementRecord = DiplomaticPlaySettlementRecord(
            playId: playId,
            turn: turn,
            concedingFaction: actingFaction,
            beneficiaryFaction: beneficiaryFaction,
            warGoal: play.warGoal,
            summary: Self.settlementSummary(
                warGoal: play.warGoal,
                concedingFaction: actingFaction,
                beneficiaryFaction: beneficiaryFaction
            ),
            concedingWarSupportDelta: concedingWarSupportDelta,
            beneficiaryWarSupportDelta: beneficiaryWarSupportDelta
        )
        diplomaticPlays[index].outcome = .negotiatedSettlement
        lastUpdatedTurn = turn
        return diplomaticPlays[index]
    }

    func canSupportDiplomaticPlay(
        actingFaction: Faction,
        playId: String,
        side: DiplomaticPlaySupportSide,
        turn: Int
    ) -> Bool {
        guard actingFaction.participatesInTurnOrder,
              !actingFaction.isNeutral,
              !countries(for: actingFaction).isEmpty,
              let play = diplomaticPlay(id: playId),
              play.outcome == .active else {
            return false
        }

        guard relationStatus(between: play.issuerFaction, and: play.targetFaction) != .atWar else {
            return false
        }

        guard !truceIsActive(between: play.issuerFaction, and: play.targetFaction, turn: turn) else {
            return false
        }

        guard actingFaction != play.issuerFaction,
              actingFaction != play.targetFaction,
              !play.backers.contains(actingFaction),
              !play.opposingBackers.contains(actingFaction) else {
            return false
        }

        let sideFaction = faction(for: side, in: play)
        guard relationStatus(between: actingFaction, and: sideFaction) != .atWar else {
            return false
        }

        guard !truceIsActive(between: actingFaction, and: play.issuerFaction, turn: turn),
              !truceIsActive(between: actingFaction, and: play.targetFaction, turn: turn) else {
            return false
        }

        return true
    }

    func canRespondToDiplomaticPlay(
        actingFaction: Faction,
        playId: String,
        stance: DiplomaticPlayAIStance,
        turn: Int
    ) -> Bool {
        guard actingFaction.participatesInTurnOrder,
              !actingFaction.isNeutral,
              !countries(for: actingFaction).isEmpty,
              let play = diplomaticPlay(id: playId),
              play.outcome == .active else {
            return false
        }

        guard relationStatus(between: play.issuerFaction, and: play.targetFaction) != .atWar else {
            return false
        }

        guard actingFaction != play.issuerFaction,
              actingFaction != play.targetFaction,
              !play.backers.contains(actingFaction),
              !play.opposingBackers.contains(actingFaction) else {
            return false
        }

        if let side = stance.supportSide {
            return canSupportDiplomaticPlay(actingFaction: actingFaction, playId: playId, side: side, turn: turn)
        }

        return relationStatus(between: actingFaction, and: play.issuerFaction) != .atWar &&
            relationStatus(between: actingFaction, and: play.targetFaction) != .atWar
    }

    @discardableResult
    mutating func supportDiplomaticPlay(
        playId: String,
        actingFaction: Faction,
        side: DiplomaticPlaySupportSide,
        turn: Int
    ) -> DiplomaticPlay? {
        guard canSupportDiplomaticPlay(actingFaction: actingFaction, playId: playId, side: side, turn: turn),
              let index = diplomaticPlays.firstIndex(where: { $0.id == playId }) else {
            return nil
        }

        switch side {
        case .issuer:
            diplomaticPlays[index].backers.append(actingFaction)
        case .target:
            diplomaticPlays[index].opposingBackers.append(actingFaction)
        }
        diplomaticPlays[index].backers = Self.sortedUniqueFactions(diplomaticPlays[index].backers)
        diplomaticPlays[index].opposingBackers = Self.sortedUniqueFactions(diplomaticPlays[index].opposingBackers)
        lastUpdatedTurn = turn
        return diplomaticPlays[index]
    }

    @discardableResult
    mutating func recordDiplomaticPlayStance(_ record: DiplomaticPlayStanceRecord) -> DiplomaticPlayStanceRecord? {
        guard let index = diplomaticPlays.firstIndex(where: { $0.id == record.playId }) else {
            return nil
        }

        diplomaticPlays[index].aiStanceRecords.removeAll {
            $0.turn == record.turn &&
                $0.faction == record.faction &&
                $0.agentId == record.agentId
        }
        diplomaticPlays[index].aiStanceRecords.append(record)
        diplomaticPlays[index].aiStanceRecords.sort {
            if $0.turn != $1.turn {
                return $0.turn < $1.turn
            }
            if $0.faction.rawValue != $1.faction.rawValue {
                return $0.faction.rawValue < $1.faction.rawValue
            }
            return $0.id < $1.id
        }
        if diplomaticPlays[index].aiStanceRecords.count > 20 {
            diplomaticPlays[index].aiStanceRecords.removeFirst(diplomaticPlays[index].aiStanceRecords.count - 20)
        }
        lastUpdatedTurn = record.turn
        return record
    }

    @discardableResult
    mutating func advanceDiplomaticPlays(turn: Int, escalationStep: Int = 25) -> [DiplomaticPlayAdvanceRecord] {
        var records: [DiplomaticPlayAdvanceRecord] = []

        for index in diplomaticPlays.indices where diplomaticPlays[index].outcome == .active {
            if relationStatus(
                between: diplomaticPlays[index].issuerFaction,
                and: diplomaticPlays[index].targetFaction
            ) == .atWar {
                diplomaticPlays[index].escalation = 100
                diplomaticPlays[index].outcome = .escalatedToWar
                records.append(advanceRecord(for: diplomaticPlays[index], didEscalateToWar: false))
                continue
            }

            diplomaticPlays[index].escalation = min(
                100,
                diplomaticPlays[index].escalation + max(0, escalationStep)
            )

            if turn >= diplomaticPlays[index].deadlineTurn {
                diplomaticPlays[index].escalation = 100
                let didDeclareWar = escalateDiplomaticPlayToWar(
                    diplomaticPlays[index],
                    turn: turn
                )
                if didDeclareWar || diplomaticPlayHasCrossSideWar(diplomaticPlays[index]) {
                    diplomaticPlays[index].escalation = 100
                    diplomaticPlays[index].outcome = .escalatedToWar
                }
                records.append(advanceRecord(for: diplomaticPlays[index], didEscalateToWar: didDeclareWar))
            } else {
                records.append(advanceRecord(for: diplomaticPlays[index], didEscalateToWar: false))
            }
        }

        if !records.isEmpty {
            lastUpdatedTurn = turn
        }
        return records
    }

    func canDeclareWar(actingFaction: Faction, targetFaction: Faction, turn: Int) -> Bool {
        guard actingFaction != targetFaction,
              actingFaction.participatesInTurnOrder,
              targetFaction.participatesInTurnOrder,
              !targetFaction.isNeutral else {
            return false
        }

        guard !countries(for: actingFaction).isEmpty,
              !countries(for: targetFaction).isEmpty else {
            return false
        }

        let relation = relationStatus(between: actingFaction, and: targetFaction)
        guard relation != .atWar else {
            return false
        }
        if relation == .truce {
            guard !truceIsActive(between: actingFaction, and: targetFaction, turn: turn) else {
                return false
            }
        }
        return true
    }

    @discardableResult
    mutating func declareWar(actingFaction: Faction, targetFaction: Faction, turn: Int) -> Bool {
        guard canDeclareWar(actingFaction: actingFaction, targetFaction: targetFaction, turn: turn) else {
            return false
        }

        let actingCountries = countries(for: actingFaction)
        let targetCountries = countries(for: targetFaction)
        for actingCountry in actingCountries {
            for targetCountry in targetCountries where actingCountry.id != targetCountry.id {
                let relation = DiplomaticRelation(
                    firstCountryId: actingCountry.id,
                    secondCountryId: targetCountry.id,
                    status: .atWar,
                    tension: 100,
                    sinceTurn: turn
                )
                if let index = relations.firstIndex(where: { $0.id == relation.id }) {
                    relations[index].status = .atWar
                    relations[index].tension = 100
                    relations[index].sinceTurn = max(1, turn)
                } else {
                    relations.append(relation)
                }
            }
        }

        relations.sort { $0.id < $1.id }
        closeActiveDiplomaticPlaysBetween(actingFaction, and: targetFaction, turn: turn)
        lastUpdatedTurn = turn
        return true
    }

    func canImposeBlockade(actingFaction: Faction, targetFaction: Faction, turn: Int) -> Bool {
        guard actingFaction != targetFaction,
              actingFaction.participatesInTurnOrder,
              targetFaction.participatesInTurnOrder,
              !targetFaction.isNeutral else {
            return false
        }

        guard !countries(for: actingFaction).isEmpty,
              !countries(for: targetFaction).isEmpty else {
            return false
        }

        let relation = relationStatus(between: actingFaction, and: targetFaction)
        switch relation {
        case .hostile, .neutral:
            return true
        case .truce:
            return !truceIsActive(between: actingFaction, and: targetFaction, turn: turn)
        case .allied, .coBelligerent, .militaryAccess, .atWar, .blockaded:
            return false
        }
    }

    @discardableResult
    mutating func imposeBlockade(actingFaction: Faction, targetFaction: Faction, turn: Int) -> Bool {
        guard canImposeBlockade(actingFaction: actingFaction, targetFaction: targetFaction, turn: turn) else {
            return false
        }

        setRelationStatus(
            between: actingFaction,
            and: targetFaction,
            status: .blockaded,
            tension: Self.tension(for: .blockaded),
            turn: turn
        )
        relations.sort { $0.id < $1.id }
        lastUpdatedTurn = turn
        return true
    }

    func canNegotiateTruce(actingFaction: Faction, playId: String) -> Bool {
        guard actingFaction.participatesInTurnOrder,
              let play = diplomaticPlay(id: playId),
              play.outcome == .escalatedToWar,
              play.issuerFaction == actingFaction || play.targetFaction == actingFaction else {
            return false
        }

        return diplomaticPlayHasCrossSideWar(play)
    }

    @discardableResult
    mutating func negotiateTruce(playId: String, actingFaction: Faction, turn: Int) -> DiplomaticPlay? {
        guard canNegotiateTruce(actingFaction: actingFaction, playId: playId),
              let index = diplomaticPlays.firstIndex(where: { $0.id == playId }) else {
            return nil
        }

        let play = diplomaticPlays[index]
        let issuerSide = Self.sortedUniqueFactions(play.backers + [play.issuerFaction])
        let targetSide = Self.sortedUniqueFactions(play.opposingBackers + [play.targetFaction])

        for issuerFaction in issuerSide {
            for targetFaction in targetSide where issuerFaction != targetFaction {
                guard relationStatus(between: issuerFaction, and: targetFaction) == .atWar else {
                    continue
                }
                setRelationStatus(
                    between: issuerFaction,
                    and: targetFaction,
                    status: .truce,
                    tension: Self.tension(for: .truce),
                    turn: turn
                )
            }
        }

        diplomaticPlays[index].outcome = .truceSettlement
        diplomaticPlays[index].escalation = 100
        relations.sort { $0.id < $1.id }
        lastUpdatedTurn = turn
        return diplomaticPlays[index]
    }

    private mutating func closeActiveDiplomaticPlaysBetween(_ lhs: Faction, and rhs: Faction, turn: Int) {
        for index in diplomaticPlays.indices where diplomaticPlays[index].outcome == .active {
            guard diplomaticPlaySidesAreOpposed(diplomaticPlays[index], lhs, rhs) else {
                continue
            }

            diplomaticPlays[index].escalation = 100
            diplomaticPlays[index].outcome = .escalatedToWar
        }

        lastUpdatedTurn = turn
    }

    private mutating func setRelationStatus(
        between lhs: Faction,
        and rhs: Faction,
        status: DiplomaticStatus,
        tension: Int,
        turn: Int
    ) {
        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        for lhsCountry in lhsCountries {
            for rhsCountry in rhsCountries where lhsCountry.id != rhsCountry.id {
                let relation = DiplomaticRelation(
                    firstCountryId: lhsCountry.id,
                    secondCountryId: rhsCountry.id,
                    status: status,
                    tension: tension,
                    sinceTurn: turn
                )
                if let index = relations.firstIndex(where: { $0.id == relation.id }) {
                    relations[index].status = status
                    relations[index].tension = tension
                    relations[index].sinceTurn = max(1, turn)
                } else {
                    relations.append(relation)
                }
            }
        }
    }

    private func diplomaticPlaySidesAreOpposed(_ play: DiplomaticPlay, _ lhs: Faction, _ rhs: Faction) -> Bool {
        let issuerSide = Self.sortedUniqueFactions(play.backers + [play.issuerFaction])
        let targetSide = Self.sortedUniqueFactions(play.opposingBackers + [play.targetFaction])

        return (issuerSide.contains(lhs) && targetSide.contains(rhs)) ||
            (issuerSide.contains(rhs) && targetSide.contains(lhs))
    }

    private mutating func escalateDiplomaticPlayToWar(_ play: DiplomaticPlay, turn: Int) -> Bool {
        let issuerSide = Self.sortedUniqueFactions(play.backers + [play.issuerFaction])
        let targetSide = Self.sortedUniqueFactions(play.opposingBackers + [play.targetFaction])
        var didDeclareWar = false

        for issuerFaction in issuerSide {
            for targetFaction in targetSide where issuerFaction != targetFaction {
                if declareWar(actingFaction: issuerFaction, targetFaction: targetFaction, turn: turn) {
                    didDeclareWar = true
                }
            }
        }

        return didDeclareWar
    }

    private func diplomaticPlayHasCrossSideWar(_ play: DiplomaticPlay) -> Bool {
        let issuerSide = Self.sortedUniqueFactions(play.backers + [play.issuerFaction])
        let targetSide = Self.sortedUniqueFactions(play.opposingBackers + [play.targetFaction])

        for issuerFaction in issuerSide {
            for targetFaction in targetSide where issuerFaction != targetFaction {
                if relationStatus(between: issuerFaction, and: targetFaction) == .atWar {
                    return true
                }
            }
        }

        return false
    }

    func relationStatus(between lhs: Faction, and rhs: Faction) -> DiplomaticStatus {
        guard lhs != rhs else {
            return lhs.isNeutral ? .neutral : .allied
        }
        guard !lhs.isNeutral, !rhs.isNeutral else {
            return .neutral
        }

        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        guard !lhsCountries.isEmpty, !rhsCountries.isEmpty else {
            if lhs.isLegacyPower && rhs.isLegacyPower {
                return .atWar
            }
            return .neutral
        }

        var statuses: [DiplomaticStatus] = []
        for lhsCountry in lhsCountries {
            for rhsCountry in rhsCountries {
                statuses.append(relation(between: lhsCountry.id, and: rhsCountry.id)?.status ?? .neutral)
            }
        }

        if statuses.contains(.atWar) {
            return .atWar
        }
        if statuses.contains(.hostile) {
            return .hostile
        }
        if statuses.contains(.blockaded) {
            return .blockaded
        }
        if statuses.contains(.truce) {
            return .truce
        }
        if statuses.contains(.militaryAccess) {
            return .militaryAccess
        }
        if statuses.contains(.coBelligerent) {
            return .coBelligerent
        }
        if statuses.contains(.allied) {
            return .allied
        }
        return .neutral
    }

    func isHostile(_ lhs: Faction, toward rhs: Faction) -> Bool {
        relationStatus(between: lhs, and: rhs).isHostile
    }

    func isFriendly(_ lhs: Faction, toward rhs: Faction) -> Bool {
        switch relationStatus(between: lhs, and: rhs) {
        case .allied, .coBelligerent, .militaryAccess:
            return true
        case .neutral, .hostile, .atWar, .truce, .blockaded:
            return false
        }
    }

    func canAttack(attacker: Faction, target: Faction) -> Bool {
        guard attacker != target, !attacker.isNeutral, !target.isNeutral else {
            return false
        }
        return relationStatus(between: attacker, and: target).allowsAttack
    }

    func canEnterTerritory(faction: Faction, controller: Faction?) -> Bool {
        guard let controller, controller != faction else {
            return true
        }
        guard !faction.isNeutral, !controller.isNeutral else {
            return false
        }
        return relationStatus(between: faction, and: controller).allowsTerritoryEntry
    }

    func hostileCountryIds(to faction: Faction) -> [CountryId] {
        let ownCountryIds = Set(countries(for: faction).map(\.id))
        var hostileCountryIds: Set<CountryId> = []
        for relation in relations where relation.status.isHostile {
            let touchesOwnCountry = ownCountryIds.contains(relation.firstCountryId) ||
                ownCountryIds.contains(relation.secondCountryId)
            guard touchesOwnCountry else {
                continue
            }
            if !ownCountryIds.contains(relation.firstCountryId) {
                hostileCountryIds.insert(relation.firstCountryId)
            }
            if !ownCountryIds.contains(relation.secondCountryId) {
                hostileCountryIds.insert(relation.secondCountryId)
            }
        }
        return hostileCountryIds.sorted { $0.rawValue < $1.rawValue }
    }

    func summary(for faction: Faction) -> String {
        let countryNames = countries(for: faction).map(\.name).joined(separator: ", ")
        let hostileCount = hostileCountryIds(to: faction).count
        return "\(faction.displayName): \(countryNames.isEmpty ? "no countries" : countryNames); \(hostileCount) hostile relation(s)."
    }

    mutating func appendRulerRecord(_ record: RulerDecisionRecord) {
        rulerRecords.append(record)
        if rulerRecords.count > 40 {
            rulerRecords.removeFirst(rulerRecords.count - 40)
        }
        lastUpdatedTurn = record.turn
    }

    @discardableResult
    mutating func adjustWarSupport(for faction: Faction, delta: Int, turn: Int) -> [WarSupportAdjustment] {
        guard delta != 0 else {
            return []
        }

        var adjustments: [WarSupportAdjustment] = []
        for index in countries.indices where countries[index].faction == faction {
            let oldValue = countries[index].warSupport
            let newValue = max(0, min(100, oldValue + delta))
            guard newValue != oldValue else {
                continue
            }

            countries[index].warSupport = newValue
            adjustments.append(
                WarSupportAdjustment(
                    countryId: countries[index].id,
                    countryName: countries[index].name,
                    oldValue: oldValue,
                    newValue: newValue
                )
            )
        }

        if !adjustments.isEmpty {
            lastUpdatedTurn = turn
        }
        return adjustments
    }

    private static func makeInitialRelations(countries: [CountryProfile], turn: Int) -> [DiplomaticRelation] {
        var relations: [DiplomaticRelation] = []
        for lhsIndex in countries.indices {
            for rhsIndex in countries.indices where rhsIndex > lhsIndex {
                let lhs = countries[lhsIndex]
                let rhs = countries[rhsIndex]
                let status = initialStatus(lhs: lhs.faction, rhs: rhs.faction)
                relations.append(
                    DiplomaticRelation(
                        firstCountryId: lhs.id,
                        secondCountryId: rhs.id,
                        status: status,
                        tension: status == .atWar ? 100 : 10,
                        sinceTurn: turn
                    )
                )
            }
        }
        return relations
    }

    private static func warSupportDelta(from oldValue: Int?, to newValue: Int?) -> Int {
        guard let oldValue, let newValue else {
            return 0
        }
        return newValue - oldValue
    }

    private static func settlementSummary(
        warGoal: DiplomaticPlayWarGoal,
        concedingFaction: Faction,
        beneficiaryFaction: Faction
    ) -> String {
        switch warGoal {
        case .protectOttomanTerritory:
            return "\(concedingFaction.displayName) accepts protections for Ottoman territory demanded by \(beneficiaryFaction.displayName)."
        case .demandDanubianWithdrawal:
            return "\(concedingFaction.displayName) accepts a Danubian withdrawal formula favoring \(beneficiaryFaction.displayName)."
        case .controlBlackSeaPort:
            return "\(concedingFaction.displayName) accepts port access terms favoring \(beneficiaryFaction.displayName)."
        case .keepStraitsOpen:
            return "\(concedingFaction.displayName) accepts open Straits guarantees favoring \(beneficiaryFaction.displayName)."
        case .weakenPrestige:
            return "\(concedingFaction.displayName) concedes prestige to keep \(beneficiaryFaction.displayName) out of war."
        }
    }

    private static func matchesDiplomaticPlay(
        _ play: DiplomaticPlay,
        lhs: Faction,
        rhs: Faction,
        regionId: RegionId?
    ) -> Bool {
        let samePair = (play.issuerFaction == lhs && play.targetFaction == rhs) ||
            (play.issuerFaction == rhs && play.targetFaction == lhs)
        return samePair && play.regionId == regionId
    }

    private static func makeBlackSeaCrisisRelations(countries: [CountryProfile], turn: Int) -> [DiplomaticRelation] {
        var relations: [DiplomaticRelation] = []
        for lhsIndex in countries.indices {
            for rhsIndex in countries.indices where rhsIndex > lhsIndex {
                let lhs = countries[lhsIndex]
                let rhs = countries[rhsIndex]
                let status = blackSeaCrisisStatus(lhs: lhs.faction, rhs: rhs.faction)
                relations.append(
                    DiplomaticRelation(
                        firstCountryId: lhs.id,
                        secondCountryId: rhs.id,
                        status: status,
                        tension: tension(for: status),
                        sinceTurn: turn
                    )
                )
            }
        }
        return relations
    }

    private static func blackSeaCrisisStatus(lhs: Faction, rhs: Faction) -> DiplomaticStatus {
        if lhs == rhs {
            return lhs.isNeutral ? .neutral : .allied
        }
        if lhs.isNeutral || rhs.isNeutral {
            return .neutral
        }
        if lhs.isLegacyPower && rhs.isLegacyPower {
            return .atWar
        }

        let coalition: Set<Faction> = [.britain, .france, .ottoman, .sardinia]
        if lhs == .russia && coalition.contains(rhs) ||
            rhs == .russia && coalition.contains(lhs) {
            return .atWar
        }
        if coalition.contains(lhs) && coalition.contains(rhs) {
            return .coBelligerent
        }
        if (lhs == .austria && rhs == .russia) || (lhs == .russia && rhs == .austria) {
            return .hostile
        }
        if (lhs == .austria && rhs == .ottoman) || (lhs == .ottoman && rhs == .austria) {
            return .militaryAccess
        }
        return .neutral
    }

    private static func tension(for status: DiplomaticStatus) -> Int {
        switch status {
        case .atWar:
            return 100
        case .blockaded, .hostile:
            return 75
        case .truce:
            return 45
        case .militaryAccess, .coBelligerent:
            return 25
        case .allied:
            return 15
        case .neutral:
            return 10
        }
    }

    private static func initialStatus(lhs: Faction, rhs: Faction) -> DiplomaticStatus {
        if lhs == rhs {
            return lhs.isNeutral ? .neutral : .allied
        }
        if lhs.isNeutral || rhs.isNeutral {
            return .neutral
        }
        if lhs.isLegacyPower && rhs.isLegacyPower {
            return .atWar
        }
        return .neutral
    }

    private static func appendVictorianCountryProfiles(
        for factions: [Faction],
        countries: inout [CountryProfile],
        blocs: inout [DiplomaticBloc]
    ) {
        let definitions: [(Faction, CountryId, String, DiplomaticBlocId, String, Bool, Int)] = [
            (.britain, "britain", "British Empire", "victorian_britain", "ruler_britain", true, 76),
            (.france, "france", "French Second Empire", "victorian_france", "ruler_france", true, 74),
            (.russia, "russia", "Russian Empire", "victorian_russia", "ruler_russia", true, 72),
            (.ottoman, "ottoman", "Ottoman Empire", "victorian_ottoman", "ruler_ottoman", true, 68),
            (.austria, "austria", "Austrian Empire", "victorian_austria", "ruler_austria", false, 66),
            (.sardinia, "sardinia", "Kingdom of Sardinia", "victorian_sardinia", "ruler_sardinia", false, 64),
            (.neutral, "neutral_local_powers", "Neutral Local Powers", "victorian_neutral", "ruler_neutral", false, 50)
        ]

        for (faction, id, name, blocId, rulerAgentId, isPrimary, warSupport) in definitions where factions.contains(faction) {
            countries.append(
                CountryProfile(
                    id: id,
                    name: name,
                    faction: faction,
                    blocId: blocId,
                    rulerAgentId: rulerAgentId,
                    isPrimaryBelligerent: isPrimary,
                    warSupport: warSupport
                )
            )
            blocs.append(
                DiplomaticBloc(
                    id: blocId,
                    name: name,
                    faction: faction,
                    memberCountryIds: [id]
                )
            )
        }
    }

    private static func diplomaticPlayId(
        issuerFaction: Faction,
        targetFaction: Faction,
        regionId: RegionId?,
        warGoal: DiplomaticPlayWarGoal,
        turn: Int
    ) -> String {
        let regionComponent = regionId?.rawValue ?? "general"
        return "play_\(max(1, turn))_\(issuerFaction.rawValue)_\(targetFaction.rawValue)_\(regionComponent)_\(warGoal.rawValue)"
    }

    private static func uniqueDiplomaticPlayId(baseId: String, existingIds: Set<String>) -> String {
        guard existingIds.contains(baseId) else {
            return baseId
        }

        var suffix = 2
        while existingIds.contains("\(baseId)_\(suffix)") {
            suffix += 1
        }
        return "\(baseId)_\(suffix)"
    }

    private static func sortedUniqueFactions(_ factions: [Faction]) -> [Faction] {
        Array(Set(factions)).sorted { $0.rawValue < $1.rawValue }
    }

    private func faction(for side: DiplomaticPlaySupportSide, in play: DiplomaticPlay) -> Faction {
        switch side {
        case .issuer:
            return play.issuerFaction
        case .target:
            return play.targetFaction
        }
    }

    private func advanceRecord(for play: DiplomaticPlay, didEscalateToWar: Bool) -> DiplomaticPlayAdvanceRecord {
        DiplomaticPlayAdvanceRecord(
            playId: play.id,
            issuerFaction: play.issuerFaction,
            targetFaction: play.targetFaction,
            issuerSideFactions: Self.sortedUniqueFactions(play.backers + [play.issuerFaction]),
            targetSideFactions: Self.sortedUniqueFactions(play.opposingBackers + [play.targetFaction]),
            warGoal: play.warGoal,
            escalation: play.escalation,
            deadlineTurn: play.deadlineTurn,
            outcome: play.outcome,
            didEscalateToWar: didEscalateToWar
        )
    }
}
