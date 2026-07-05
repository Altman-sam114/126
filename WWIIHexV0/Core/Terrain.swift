import Foundation

enum BaseTerrain: String, Codable, Equatable, CaseIterable {
    case plain
    case forest
    case mountain
    case hill
    case city
    case fortress

    var movementCost: Int {
        switch self {
        case .plain:
            return 1
        case .forest:
            return 2
        case .mountain:
            return 3
        case .hill:
            return 2
        case .city:
            return 1
        case .fortress:
            return 2
        }
    }

    var defenseBonus: Int {
        switch self {
        case .plain:
            return 0
        case .forest:
            return 2
        case .mountain:
            return 3
        case .hill:
            return 1
        case .city:
            return 2
        case .fortress:
            return 4
        }
    }

    var armorSlowdownCost: Int {
        switch self {
        case .plain:
            return 0
        case .hill:
            return 1
        case .forest,
             .city,
             .fortress:
            return 1
        case .mountain:
            return 2
        }
    }

    var supportsInfantryDefenseBonus: Bool {
        switch self {
        case .forest,
             .city,
             .fortress:
            return true
        case .plain,
             .mountain,
             .hill:
            return false
        }
    }

    var isObjectiveTerrain: Bool {
        self == .city || self == .fortress
    }

    var displayName: String {
        switch self {
        case .plain:
            return "Plain"
        case .forest:
            return "Forest"
        case .mountain:
            return "Mountain"
        case .hill:
            return "Hill"
        case .city:
            return "City"
        case .fortress:
            return "Fortress"
        }
    }
}

enum LogisticsTag: String, Codable, Equatable, Hashable, CaseIterable {
    case rail
    case port
    case coast
    case coalStation
    case telegraph
    case expeditionaryDepot
    case siegeDepot

    var displayName: String {
        switch self {
        case .rail:
            return "Rail"
        case .port:
            return "Port"
        case .coast:
            return "Coast"
        case .coalStation:
            return "Coal Station"
        case .telegraph:
            return "Telegraph"
        case .expeditionaryDepot:
            return "Expeditionary Depot"
        case .siegeDepot:
            return "Siege Depot"
        }
    }
}

struct HexTile: Codable, Equatable {
    let coord: HexCoord
    var baseTerrain: BaseTerrain
    var hasRoad: Bool
    var riverEdges: Set<HexDirection>
    var controller: Faction?
    var cityName: String?
    var fortressName: String?
    var isPassable: Bool
    var logisticsTags: Set<LogisticsTag>
    /// v0.2: 该 hex 所属省份。默认 nil（未分配省份），province 层叠加时由数据填充。
    /// hex 仍是战术层权威坐标，regionId 只是聚合归属标记，不影响现有 hex 规则。
    var regionId: RegionId?

    private enum CodingKeys: String, CodingKey {
        case coord
        case baseTerrain
        case hasRoad
        case riverEdges
        case controller
        case cityName
        case fortressName
        case isPassable
        case logisticsTags
        case regionId
    }

    init(
        coord: HexCoord,
        baseTerrain: BaseTerrain = .plain,
        hasRoad: Bool = false,
        riverEdges: Set<HexDirection> = [],
        controller: Faction? = nil,
        cityName: String? = nil,
        fortressName: String? = nil,
        isPassable: Bool = true,
        logisticsTags: Set<LogisticsTag> = [],
        regionId: RegionId? = nil
    ) {
        self.coord = coord
        self.baseTerrain = baseTerrain
        self.hasRoad = hasRoad
        self.riverEdges = riverEdges
        self.controller = controller
        self.cityName = cityName
        self.fortressName = fortressName
        self.isPassable = isPassable
        self.logisticsTags = logisticsTags
        self.regionId = regionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            coord: try container.decode(HexCoord.self, forKey: .coord),
            baseTerrain: try container.decodeIfPresent(BaseTerrain.self, forKey: .baseTerrain) ?? .plain,
            hasRoad: try container.decodeIfPresent(Bool.self, forKey: .hasRoad) ?? false,
            riverEdges: try container.decodeIfPresent(Set<HexDirection>.self, forKey: .riverEdges) ?? [],
            controller: try container.decodeIfPresent(Faction.self, forKey: .controller),
            cityName: try container.decodeIfPresent(String.self, forKey: .cityName),
            fortressName: try container.decodeIfPresent(String.self, forKey: .fortressName),
            isPassable: try container.decodeIfPresent(Bool.self, forKey: .isPassable) ?? true,
            logisticsTags: try container.decodeIfPresent(Set<LogisticsTag>.self, forKey: .logisticsTags) ?? [],
            regionId: try container.decodeIfPresent(RegionId.self, forKey: .regionId)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coord, forKey: .coord)
        try container.encode(baseTerrain, forKey: .baseTerrain)
        try container.encode(hasRoad, forKey: .hasRoad)
        try container.encode(riverEdges, forKey: .riverEdges)
        try container.encodeIfPresent(controller, forKey: .controller)
        try container.encodeIfPresent(cityName, forKey: .cityName)
        try container.encodeIfPresent(fortressName, forKey: .fortressName)
        try container.encode(isPassable, forKey: .isPassable)
        if !logisticsTags.isEmpty {
            try container.encode(logisticsTags.sorted { $0.rawValue < $1.rawValue }, forKey: .logisticsTags)
        }
        try container.encodeIfPresent(regionId, forKey: .regionId)
    }

    var isCapturable: Bool {
        isPassable
    }
}
