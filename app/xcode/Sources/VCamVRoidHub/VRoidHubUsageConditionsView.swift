import SwiftUI
import VRoidSDK

/// Displays a model's conditions of use with the exact labels, values, and
/// order required by the official guideline:
/// https://developer.vroid.com/guidelines/conditions_of_use.html
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
                    if let politicalOrReligiousUsage = conditions.politicalOrReligiousUsage {
                        row(.conditionPoliticalReligiousUse, permission(politicalOrReligiousUsage))
                    }
                    if let antisocialOrHateUsage = conditions.antisocialOrHateUsage {
                        row(.conditionAntisocialHateUse, permission(antisocialOrHateUsage))
                    }
                    row(.conditionCorporateCommercialUse, permission(conditions.corporateCommercialUse))
                    row(.conditionPersonalCommercialUse, personalCommercialUse(conditions.personalCommercialUse))
                    row(.conditionRedistribution, permission(conditions.redistribution))
                    row(.conditionModification, permission(conditions.modification))
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
        // The guideline displays avatar use as a binary: only "everyone" is an allow
        switch characterization {
        case .everyone: Text(.permissionAllowed)
        case .authorOnly, .separatelyLicensedPersonOnly: Text(.permissionDisallowed)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }

    private func personalCommercialUse(_ use: VRoidUsageConditions.PersonalCommercialUse) -> Text {
        switch use {
        case .allowed, .profitAllowed: Text(.permissionAllowed)
        case .nonprofitAllowed: Text(.personalCommercialNonprofit)
        case .disallowed: Text(.permissionDisallowed)
        case .unspecified: Text(.permissionUnspecified)
        case .unknown(let raw): Text(verbatim: raw)
        }
    }
}
