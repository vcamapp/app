import SwiftUI
import VRoidSDK

struct VRoidHubUsageConditionsView: View {
    let conditions: VRoidUsageConditions?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(.usageConditions)
                .font(.headline)

            if let conditions {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    row(.conditionUseAsAvatar, characterization(conditions.characterization))
                    row(.conditionViolentExpressions, permission(conditions.violentExpression))
                    row(.conditionSexualExpressions, permission(conditions.sexualExpression))
                    row(.conditionCorporateCommercialUse, permission(conditions.corporateCommercialUse))
                    row(.conditionPersonalCommercialUse, personalCommercialUse(conditions.personalCommercialUse))
                    if let politicalOrReligiousUsage = conditions.politicalOrReligiousUsage {
                        row(.conditionPoliticalReligiousUse, permission(politicalOrReligiousUsage))
                    }
                    if let antisocialOrHateUsage = conditions.antisocialOrHateUsage {
                        row(.conditionAntisocialHateUse, permission(antisocialOrHateUsage))
                    }
                    row(.conditionModification, permission(conditions.modification))
                    row(.conditionRedistribution, permission(conditions.redistribution))
                    if let modifiedRedistribution = conditions.modifiedRedistribution {
                        row(.conditionModifiedRedistribution, permission(modifiedRedistribution))
                    }
                    row(.conditionCredit, credit(conditions.credit))
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

    private func row(_ label: LocalizedStringResource, _ value: Text) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            value
        }
    }

    private func permission(_ permission: VRoidUsageConditions.Permission) -> Text {
        switch permission {
        case .allowed: Text(.permissionAllowed)
        case .disallowed: Text(.permissionDisallowed)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }

    private func credit(_ credit: VRoidUsageConditions.CreditRequirement) -> Text {
        switch credit {
        case .required: Text(.creditRequired)
        case .unnecessary: Text(.creditUnnecessary)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }

    private func characterization(_ characterization: VRoidUsageConditions.CharacterizationPermission) -> Text {
        switch characterization {
        case .authorOnly: Text(.characterizationAuthorOnly)
        case .separatelyLicensedPersonOnly: Text(.characterizationLicensedOnly)
        case .everyone: Text(.characterizationEveryone)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }

    private func personalCommercialUse(_ use: VRoidUsageConditions.PersonalCommercialUse) -> Text {
        switch use {
        case .allowed: Text(.permissionAllowed)
        case .profitAllowed: Text(.personalCommercialProfit)
        case .nonprofitAllowed: Text(.personalCommercialNonprofit)
        case .disallowed: Text(.permissionDisallowed)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }
}
