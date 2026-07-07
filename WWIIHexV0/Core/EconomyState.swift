import Foundation

struct EconomyResources: Codable, Equatable {
    var manpower: Int
    var industry: Int
    var supplies: Int

    init(manpower: Int = 0, industry: Int = 0, supplies: Int = 0) {
        self.manpower = max(0, manpower)
        self.industry = max(0, industry)
        self.supplies = max(0, supplies)
    }

    static var zero: EconomyResources {
        EconomyResources()
    }

    var isEmpty: Bool {
        manpower == 0 && industry == 0 && supplies == 0
    }

    func canAfford(_ cost: EconomyResources) -> Bool {
        manpower >= cost.manpower &&
            industry >= cost.industry &&
            supplies >= cost.supplies
    }

    mutating func add(_ resources: EconomyResources) {
        manpower = max(0, manpower + resources.manpower)
        industry = max(0, industry + resources.industry)
        supplies = max(0, supplies + resources.supplies)
    }

    mutating func subtract(_ resources: EconomyResources) {
        manpower = max(0, manpower - resources.manpower)
        industry = max(0, industry - resources.industry)
        supplies = max(0, supplies - resources.supplies)
    }

    var victorianSummary: String {
        "REC \(manpower), TRE \(industry), STO \(supplies)"
    }
}

enum CityLevel: String, Codable, Equatable, CaseIterable {
    case none
    case village
    case town
    case metropolis

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .village:
            return "Village"
        case .town:
            return "Town"
        case .metropolis:
            return "Metropolis"
        }
    }

    var industryValue: Int {
        switch self {
        case .none:
            return 0
        case .village:
            return 1
        case .town:
            return 3
        case .metropolis:
            return 6
        }
    }

    var manpowerGrowth: Int {
        switch self {
        case .none:
            return 0
        case .village:
            return 8
        case .town:
            return 20
        case .metropolis:
            return 45
        }
    }
}

enum ProductionKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case lineInfantryCorps
    case guardBrigade
    case cavalryBrigade
    case siegeArtilleryBattery
    case supplyConvoy

    case infantryDivision
    case panzerDivision
    case motorizedDivision
    case artilleryDivision
    case supplyStockpile

    static let allCases: [ProductionKind] = [
        .lineInfantryCorps,
        .guardBrigade,
        .cavalryBrigade,
        .siegeArtilleryBattery,
        .supplyConvoy
    ]

    var id: String {
        rawValue
    }

    var victorianKind: ProductionKind {
        switch self {
        case .infantryDivision:
            return .lineInfantryCorps
        case .panzerDivision:
            return .guardBrigade
        case .motorizedDivision:
            return .cavalryBrigade
        case .artilleryDivision:
            return .siegeArtilleryBattery
        case .supplyStockpile:
            return .supplyConvoy
        case .lineInfantryCorps,
             .guardBrigade,
             .cavalryBrigade,
             .siegeArtilleryBattery,
             .supplyConvoy:
            return self
        }
    }

    var displayName: String {
        switch self {
        case .lineInfantryCorps,
             .infantryDivision:
            return "Line Infantry Corps"
        case .guardBrigade,
             .panzerDivision:
            return "Guard Brigade"
        case .cavalryBrigade,
             .motorizedDivision:
            return "Cavalry Brigade"
        case .siegeArtilleryBattery,
             .artilleryDivision:
            return "Siege Artillery Battery"
        case .supplyConvoy,
             .supplyStockpile:
            return "Supply Convoy"
        }
    }

    var cost: EconomyResources {
        switch self {
        case .lineInfantryCorps,
             .infantryDivision:
            return EconomyResources(manpower: 90, industry: 35, supplies: 12)
        case .guardBrigade,
             .panzerDivision:
            return EconomyResources(manpower: 70, industry: 95, supplies: 24)
        case .cavalryBrigade,
             .motorizedDivision:
            return EconomyResources(manpower: 80, industry: 65, supplies: 18)
        case .siegeArtilleryBattery,
             .artilleryDivision:
            return EconomyResources(manpower: 55, industry: 55, supplies: 14)
        case .supplyConvoy,
             .supplyStockpile:
            return EconomyResources(manpower: 0, industry: 25, supplies: 0)
        }
    }

    var buildTurns: Int {
        switch self {
        case .lineInfantryCorps,
             .infantryDivision:
            return 2
        case .guardBrigade,
             .panzerDivision:
            return 4
        case .cavalryBrigade,
             .motorizedDivision:
            return 3
        case .siegeArtilleryBattery,
             .artilleryDivision:
            return 2
        case .supplyConvoy,
             .supplyStockpile:
            return 1
        }
    }

    var supplyOutput: Int {
        switch self {
        case .supplyConvoy,
             .supplyStockpile:
            return 85
        case .lineInfantryCorps,
             .guardBrigade,
             .cavalryBrigade,
             .siegeArtilleryBattery,
             .infantryDivision,
             .panzerDivision,
             .motorizedDivision,
             .artilleryDivision:
            return 0
        }
    }

    var producesSupplyOnly: Bool {
        switch self {
        case .supplyConvoy,
             .supplyStockpile:
            return true
        case .lineInfantryCorps,
             .guardBrigade,
             .cavalryBrigade,
             .siegeArtilleryBattery,
             .infantryDivision,
             .panzerDivision,
             .motorizedDivision,
             .artilleryDivision:
            return false
        }
    }
}

enum EconomyCommand: String, Codable, Equatable, CaseIterable, Identifiable {
    case mobilizeReserves
    case raiseWarLoan
    case buySupplies

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .mobilizeReserves:
            return "Mobilize Reserves"
        case .raiseWarLoan:
            return "Raise War Loan"
        case .buySupplies:
            return "Buy Stores"
        }
    }

    var systemImageName: String {
        switch self {
        case .mobilizeReserves:
            return "person.3.fill"
        case .raiseWarLoan:
            return "banknote"
        case .buySupplies:
            return "shippingbox"
        }
    }

    var cost: EconomyResources {
        switch self {
        case .mobilizeReserves:
            return EconomyResources(industry: 45, supplies: 20)
        case .raiseWarLoan:
            return .zero
        case .buySupplies:
            return EconomyResources(industry: 35)
        }
    }

    var immediateYield: EconomyResources {
        switch self {
        case .mobilizeReserves:
            return EconomyResources(manpower: 90)
        case .raiseWarLoan:
            return EconomyResources(industry: 120)
        case .buySupplies:
            return EconomyResources(supplies: 90)
        }
    }

    var debtIncrease: Int {
        switch self {
        case .mobilizeReserves:
            return 0
        case .raiseWarLoan:
            return 160
        case .buySupplies:
            return 0
        }
    }
}

enum ConstructionKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case railway
    case fieldWorks
    case portWorks
    case expeditionaryDepotWorks
    case siegeDepotWorks

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .railway:
            return "Railway Works"
        case .fieldWorks:
            return "Field Works"
        case .portWorks:
            return "Port Works"
        case .expeditionaryDepotWorks:
            return "Expeditionary Depot Works"
        case .siegeDepotWorks:
            return "Siege Depot Works"
        }
    }

    var systemImageName: String {
        switch self {
        case .railway:
            return "tram.fill"
        case .fieldWorks:
            return "shield.lefthalf.filled"
        case .portWorks:
            return "ferry.fill"
        case .expeditionaryDepotWorks:
            return "shippingbox.fill"
        case .siegeDepotWorks:
            return "scope"
        }
    }

    var cost: EconomyResources {
        switch self {
        case .railway:
            return EconomyResources(manpower: 20, industry: 65, supplies: 12)
        case .fieldWorks:
            return EconomyResources(manpower: 14, industry: 35, supplies: 18)
        case .portWorks:
            return EconomyResources(manpower: 18, industry: 70, supplies: 26)
        case .expeditionaryDepotWorks:
            return EconomyResources(manpower: 16, industry: 55, supplies: 34)
        case .siegeDepotWorks:
            return EconomyResources(manpower: 16, industry: 45, supplies: 30)
        }
    }

    var buildTurns: Int {
        switch self {
        case .railway:
            return 2
        case .fieldWorks:
            return 1
        case .portWorks:
            return 2
        case .expeditionaryDepotWorks:
            return 1
        case .siegeDepotWorks:
            return 1
        }
    }

    var completedLogisticsTag: LogisticsTag {
        switch self {
        case .railway:
            return .rail
        case .fieldWorks:
            return .fieldWorks
        case .portWorks:
            return .port
        case .expeditionaryDepotWorks:
            return .expeditionaryDepot
        case .siegeDepotWorks:
            return .siegeDepot
        }
    }

    var siteRequirementDescription: String? {
        switch self {
        case .portWorks:
            return "Requires coastal hex"
        case .expeditionaryDepotWorks:
            return "Requires coastal or port hex"
        case .siegeDepotWorks:
            return "Requires adjacent enemy city or fortress"
        case .railway,
             .fieldWorks:
            return nil
        }
    }
}

struct ProductionOrder: Identifiable, Codable, Equatable {
    let id: String
    let faction: Faction
    let kind: ProductionKind
    var remainingTurns: Int
    let totalTurns: Int
    let createdTurn: Int
    var deploymentRegionId: RegionId?

    init(
        id: String,
        faction: Faction,
        kind: ProductionKind,
        remainingTurns: Int? = nil,
        totalTurns: Int? = nil,
        createdTurn: Int,
        deploymentRegionId: RegionId? = nil
    ) {
        self.id = id
        self.faction = faction
        self.kind = kind
        self.remainingTurns = max(0, remainingTurns ?? kind.buildTurns)
        self.totalTurns = max(1, totalTurns ?? kind.buildTurns)
        self.createdTurn = max(1, createdTurn)
        self.deploymentRegionId = deploymentRegionId
    }

    var isReady: Bool {
        remainingTurns == 0
    }
}

struct ConstructionOrder: Identifiable, Codable, Equatable {
    let id: String
    let faction: Faction
    let kind: ConstructionKind
    let target: HexCoord
    var remainingTurns: Int
    let totalTurns: Int
    let createdTurn: Int

    init(
        id: String,
        faction: Faction,
        kind: ConstructionKind,
        target: HexCoord,
        remainingTurns: Int? = nil,
        totalTurns: Int? = nil,
        createdTurn: Int
    ) {
        self.id = id
        self.faction = faction
        self.kind = kind
        self.target = target
        self.remainingTurns = max(0, remainingTurns ?? kind.buildTurns)
        self.totalTurns = max(1, totalTurns ?? kind.buildTurns)
        self.createdTurn = max(1, createdTurn)
    }

    var isReady: Bool {
        remainingTurns == 0
    }
}

struct FactionEconomyLedger: Codable, Equatable {
    let faction: Faction
    var stockpile: EconomyResources
    var lastIncome: EconomyResources
    var lastUpkeep: EconomyResources
    var lastReinforcementSpend: EconomyResources
    var productionQueue: [ProductionOrder]
    var constructionQueue: [ConstructionOrder]
    var warDebt: Int
    var lastUpdatedTurn: Int

    private enum CodingKeys: String, CodingKey {
        case faction
        case stockpile
        case lastIncome
        case lastUpkeep
        case lastReinforcementSpend
        case productionQueue
        case constructionQueue
        case warDebt
        case lastUpdatedTurn
    }

    init(
        faction: Faction,
        stockpile: EconomyResources = .zero,
        lastIncome: EconomyResources = .zero,
        lastUpkeep: EconomyResources = .zero,
        lastReinforcementSpend: EconomyResources = .zero,
        productionQueue: [ProductionOrder] = [],
        constructionQueue: [ConstructionOrder] = [],
        warDebt: Int = 0,
        lastUpdatedTurn: Int = 1
    ) {
        self.faction = faction
        self.stockpile = stockpile
        self.lastIncome = lastIncome
        self.lastUpkeep = lastUpkeep
        self.lastReinforcementSpend = lastReinforcementSpend
        self.productionQueue = productionQueue
        self.constructionQueue = constructionQueue
        self.warDebt = max(0, warDebt)
        self.lastUpdatedTurn = max(1, lastUpdatedTurn)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.faction = try container.decode(Faction.self, forKey: .faction)
        self.stockpile = try container.decode(EconomyResources.self, forKey: .stockpile)
        self.lastIncome = try container.decode(EconomyResources.self, forKey: .lastIncome)
        self.lastUpkeep = try container.decode(EconomyResources.self, forKey: .lastUpkeep)
        self.lastReinforcementSpend = try container.decode(
            EconomyResources.self,
            forKey: .lastReinforcementSpend
        )
        self.productionQueue = try container.decode([ProductionOrder].self, forKey: .productionQueue)
        self.constructionQueue = try container.decodeIfPresent(
            [ConstructionOrder].self,
            forKey: .constructionQueue
        ) ?? []
        self.warDebt = max(0, try container.decodeIfPresent(Int.self, forKey: .warDebt) ?? 0)
        self.lastUpdatedTurn = max(1, try container.decode(Int.self, forKey: .lastUpdatedTurn))
    }
}

struct EconomyState: Codable, Equatable {
    var ledgers: [Faction: FactionEconomyLedger]
    var lastResolvedTurn: Int?

    init(
        ledgers: [Faction: FactionEconomyLedger] = [:],
        lastResolvedTurn: Int? = nil
    ) {
        self.ledgers = ledgers
        self.lastResolvedTurn = lastResolvedTurn
    }

    static var empty: EconomyState {
        EconomyState()
    }

    func ledger(for faction: Faction) -> FactionEconomyLedger {
        ledgers[faction] ?? FactionEconomyLedger(faction: faction)
    }

    mutating func updateLedger(_ ledger: FactionEconomyLedger) {
        ledgers[ledger.faction] = ledger
    }
}

extension Division {
    var isInfantryHeavy: Bool {
        componentWeight(for: .infantry) +
            componentWeight(for: .lineInfantry) +
            componentWeight(for: .guardInfantry) +
            componentWeight(for: .colonialInfantry) +
            componentWeight(for: .irregulars) >= 0.50
    }

    var isMechanizedHeavy: Bool {
        isMobileFormation
    }
}
