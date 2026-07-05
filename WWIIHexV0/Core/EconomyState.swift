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

struct FactionEconomyLedger: Codable, Equatable {
    let faction: Faction
    var stockpile: EconomyResources
    var lastIncome: EconomyResources
    var lastUpkeep: EconomyResources
    var lastReinforcementSpend: EconomyResources
    var productionQueue: [ProductionOrder]
    var lastUpdatedTurn: Int

    init(
        faction: Faction,
        stockpile: EconomyResources = .zero,
        lastIncome: EconomyResources = .zero,
        lastUpkeep: EconomyResources = .zero,
        lastReinforcementSpend: EconomyResources = .zero,
        productionQueue: [ProductionOrder] = [],
        lastUpdatedTurn: Int = 1
    ) {
        self.faction = faction
        self.stockpile = stockpile
        self.lastIncome = lastIncome
        self.lastUpkeep = lastUpkeep
        self.lastReinforcementSpend = lastReinforcementSpend
        self.productionQueue = productionQueue
        self.lastUpdatedTurn = max(1, lastUpdatedTurn)
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
