import SwiftUI

struct RegionInspectorView: View {
    let inspectorState: RegionInspectorState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Region")
                .font(.headline)

            if let inspectorState {
                regionDetails(inspectorState)
            } else {
                Text("No region selected.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(PlatformStyles.systemBackground)
        .clipShape(.rect(cornerRadius: 8))
    }

    private func regionDetails(_ state: RegionInspectorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.region.name)
                .font(.subheadline.weight(.semibold))

            if let selectedHex = state.selectedHex {
                LabeledContent("Hex") {
                    Text("\(selectedHex.q),\(selectedHex.r)")
                }

                LabeledContent("Hex Controller") {
                    Text(state.selectedHexController?.displayName ?? "None")
                }

                LabeledContent("Hex Dynamic Theater") {
                    Text(state.selectedHexDynamicTheaterId?.rawValue ?? "None")
                }

                LabeledContent("Hex Command Sector") {
                    Text(state.selectedHexFrontZoneId?.rawValue ?? "None")
                }

                LabeledContent("Hex Logistics") {
                    Text(logisticsTags(state.selectedHexLogisticsTags))
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent("Controller") {
                Text(state.region.controller.displayName)
            }

            LabeledContent("Terrain") {
                Text(state.region.terrain.displayName)
            }

            LabeledContent("City") {
                Text(state.region.city?.name ?? "None")
            }

            LabeledContent("City Level") {
                Text(state.cityLevel.displayName)
            }

            LabeledContent("Fortress") {
                Text(state.region.terrain == .fortress ? "Yes" : "No")
            }

            LabeledContent("Supply") {
                Text("\(state.region.supplyValue)")
            }

            LabeledContent("Factories") {
                Text("\(state.region.factories)")
            }

            LabeledContent("Output") {
                Text(state.economicOutput.victorianSummary)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Theater") {
                Text(state.theaterId?.rawValue ?? "None")
            }

            LabeledContent("Command Sector") {
                Text(state.frontZoneId?.rawValue ?? "None")
            }

            LabeledContent("Front Pressure") {
                Text(state.frontPressure, format: .number.precision(.fractionLength(2)))
            }

            LabeledContent("Infrastructure") {
                Text("\(state.region.infrastructure)")
            }

            LabeledContent("Region Logistics") {
                Text(logisticsTagCounts(state.regionLogisticsTagCounts))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Objectives") {
                Text(state.objectiveNames.isEmpty ? "None" : state.objectiveNames.joined(separator: ", "))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Objective Status") {
                Text(state.objectiveStatus)
            }

            LabeledContent("Friendly Formations") {
                Text(unitNames(state.friendlyDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Visible Enemies") {
                Text(unitNames(state.visibleEnemyDivisions))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func unitNames(_ divisions: [Division]) -> String {
        guard !divisions.isEmpty else {
            return "None"
        }
        return divisions.map(\.name).joined(separator: ", ")
    }

    private func logisticsTags(_ tags: [LogisticsTag]) -> String {
        guard !tags.isEmpty else {
            return "None"
        }
        return tags.map(\.displayName).joined(separator: ", ")
    }

    private func logisticsTagCounts(_ counts: [LogisticsTag: Int]) -> String {
        let summaries = LogisticsTag.allCases.compactMap { tag -> String? in
            guard let count = counts[tag], count > 0 else {
                return nil
            }
            return "\(tag.displayName) x\(count)"
        }

        return summaries.isEmpty ? "None" : summaries.joined(separator: ", ")
    }
}
