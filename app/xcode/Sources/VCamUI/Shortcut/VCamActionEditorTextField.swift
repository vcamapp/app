//
//  VCamActionEditorTextField.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import SwiftUI

struct VCamActionEditorTextField: View {
    @Binding var value: String

    var body: some View {
        TextField("", text: $value)
            .textFieldStyle(.roundedBorder)
    }
}

struct VCamActionEditorTextField_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorTextField(value: .constant("hello"))
    }
}
