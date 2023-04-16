//
//  VCamActionEditorNumberField.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI

struct VCamActionEditorDurationField: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
            Text(L10n.seconds.key, bundle: .localize)
        }
        .frame(width: 80)
    }
}

struct VCamActionEditorNumberField_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorDurationField(value: .constant(100))
    }
}
