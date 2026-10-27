import SwiftUI
import VRoidSDK

/// Displays a model's conditions of use with the exact labels, values, and
/// order required by the official guideline:
/// https://developer.vroid.com/guidelines/conditions_of_use.html
public struct VRoidHubUsageConditionsView: View {
    let conditions: VRoidUsageConditions?

    public init(conditions: VRoidUsageConditions?) {
        self.conditions = conditions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(.usageConditions)
                .font(.headline)

            if let conditions {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    ForEach(conditions.guidelineRows, id: \.condition) { row in
                        GridRow {
                            Text(label(row.condition))
                                .foregroundStyle(.secondary)
                            value(row.value)
                        }
                    }
                }
                .font(.callout)
            } else {
                // Never present unknown conditions as permission
                Text(.usageConditionsUnavailable)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(_ condition: VRoidUsageConditions.GuidelineCondition) -> LocalizedStringResource {
        switch condition {
        case .useAsAvatar: .conditionUseAsAvatar
        case .violentExpressions: .conditionViolentExpressions
        case .sexualExpressions: .conditionSexualExpressions
        case .politicalOrReligiousUse: .conditionPoliticalReligiousUse
        case .antisocialOrHateUse: .conditionAntisocialHateUse
        case .corporateCommercialUse: .conditionCorporateCommercialUse
        case .personalCommercialUse: .conditionPersonalCommercialUse
        case .redistribution: .conditionRedistribution
        case .modification: .conditionModification
        case .modifiedRedistribution: .conditionModifiedRedistribution
        case .credit: .conditionCredit
        }
    }

    private func value(_ value: VRoidUsageConditions.GuidelineValue) -> Text {
        switch value {
        case .allowed: Text(.permissionAllowed)
        case .disallowed: Text(.permissionDisallowed)
        case .nonprofitOnly: Text(.personalCommercialNonprofit)
        case .required: Text(.creditRequired)
        case .unnecessary: Text(.creditUnnecessary)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }
}
