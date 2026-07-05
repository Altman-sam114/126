import SwiftUI

struct UnitInspectorView: View {
    let division: Division?
    let playerFaction: Faction
    let strategicState: UnitInspectorStrategicState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Formation Details")
                .font(.headline)

            if let division {
                unitDetails(division)
            } else {
                Text("No formation selected.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func unitDetails(_ division: Division) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(division.name)
                .font(.subheadline.weight(.semibold))

            LabeledContent("Power") {
                Text(division.faction.displayName)
            }

            LabeledContent("Command") {
                Text(division.faction == playerFaction ? "Direct" : "Observer")
            }

            LabeledContent("Type") {
                Text(division.victorianFormationDisplayName)
            }

            if let strategicState {
                LabeledContent("Hex") {
                    Text("\(strategicState.coord.q),\(strategicState.coord.r)")
                }

                LabeledContent("Region") {
                    Text(strategicState.regionId?.rawValue ?? "None")
                }

                LabeledContent("Dynamic Theater") {
                    Text(strategicState.dynamicTheaterId?.rawValue ?? "None")
                }

                LabeledContent("Front Zone") {
                    Text(strategicState.frontZoneId?.rawValue ?? "None")
                }

                LabeledContent("Deploy") {
                    Text(strategicState.deploymentRole.displayName)
                }

                LabeledContent("Front Line") {
                    Text(frontLineSummary(strategicState.frontLineIds))
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent("Strength") {
                Text(division.inspectorStrengthText)
            }

            LabeledContent("Orders") {
                Text(division.retreatMode.displayName)
            }

            LabeledContent("Logistics") {
                Text(division.supplyState.displayName)
            }

            LabeledContent("Has Acted") {
                Text(division.hasActed ? "Yes" : "No")
            }

            LabeledContent("Status") {
                Text(division.inspectorStatusText)
            }

            LabeledContent("Arms") {
                Text(componentSummary(for: division))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func componentSummary(for division: Division) -> String {
        division.components
            .map { "\($0.type.victorianDisplayCode) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: " / ")
    }

    private func frontLineSummary(_ ids: [FrontLineId]) -> String {
        ids.isEmpty ? "None" : ids.map(\.rawValue).joined(separator: ", ")
    }
}

private extension Division {
    var inspectorStrengthText: String {
        "\(strength) / \(maxStrength)"
    }

    var inspectorStatusText: String {
        var statuses: [String] = []

        if isRetreating {
            statuses.append("Withdrawing")
        }

        if isDestroyed {
            statuses.append("Broken")
        }

        return statuses.isEmpty ? "Ready" : statuses.joined(separator: ", ")
    }
}

private extension RetreatMode {
    var displayName: String {
        switch self {
        case .retreatable:
            return "Withdraw Allowed"
        case .hold:
            return "Hold Ground"
        }
    }
}

private extension SupplyState {
    var displayName: String {
        switch self {
        case .supplied:
            return "Provisioned"
        case .lowSupply:
            return "Strained"
        case .encircled:
            return "Cut Off"
        }
    }
}

private extension UnitDeploymentRole {
    var displayName: String {
        switch self {
        case .frontUnit:
            return "Line"
        case .depthUnit:
            return "Reserve"
        case .garrisonUnit:
            return "Garrison"
        }
    }
}

private extension Set where Element == HexDirection {
    var displaySummary: String {
        HexDirection.ordered
            .filter { contains($0) }
            .map(\.displayCode)
            .joined(separator: ", ")
    }
}

private extension HexDirection {
    var displayCode: String {
        switch self {
        case .east:
            return "E"
        case .northEast:
            return "NE"
        case .northWest:
            return "NW"
        case .west:
            return "W"
        case .southWest:
            return "SW"
        case .southEast:
            return "SE"
        }
    }
}
