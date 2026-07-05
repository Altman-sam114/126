import SwiftUI

struct UnitTooltipView: View {
    let division: Division?

    var body: some View {
        if let division {
            VStack(alignment: .leading, spacing: 6) {
                Text(division.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        label("Formation")
                        value(division.victorianFormationDisplayCode)
                    }
                    GridRow {
                        label("Strength")
                        value("\(division.strength)/\(division.maxStrength)")
                    }
                    GridRow {
                        label("Logistics")
                        value(division.supplyState.tooltipDisplayName)
                    }
                    GridRow {
                        label("Orders")
                        value(division.retreatMode.tooltipDisplayName)
                    }
                    GridRow {
                        label("Acted")
                        value(division.hasActed ? "Yes" : "No")
                    }
                }
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
            }
            .padding(10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(division.name), \(division.victorianFormationDisplayName), strength \(division.strength) of \(division.maxStrength)")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private extension RetreatMode {
    var tooltipDisplayName: String {
        switch self {
        case .retreatable:
            return "Withdraw"
        case .hold:
            return "Hold"
        }
    }
}

private extension SupplyState {
    var tooltipDisplayName: String {
        switch self {
        case .supplied:
            return "Ready"
        case .lowSupply:
            return "Strained"
        case .encircled:
            return "Cut Off"
        }
    }
}
