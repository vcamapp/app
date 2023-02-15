//
//  VCamMainToolbarPhotoPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamUIFoundation

public struct VCamMainToolbarPhotoPicker: View {
    public init(backgroundColor: Binding<Color>, loadBackgroundImage: @escaping (URL) -> Void, removeBackgroundImage: @escaping () -> Void) {
        self._backgroundColor = backgroundColor
        self.loadBackgroundImage = loadBackgroundImage
        self.removeBackgroundImage = removeBackgroundImage
    }

    @Binding var backgroundColor: Color

    let loadBackgroundImage: (URL) -> Void
    let removeBackgroundImage: () -> Void

    public var body: some View {
        GroupBox {
            Form {
                HStack {
                    Text(L10n.color.key, bundle: .localize)
                        .fixedSize(horizontal: true, vertical: false)
                    ColorEditField(L10n.color.key, value: $backgroundColor)
                        .labelsHidden()
                }
                HStack {
                    Text(L10n.image.key, bundle: .localize)
                        .fixedSize(horizontal: true, vertical: false)
                    Button {
                        if let url = FileUtility.openFile(type: .image) {
                            loadBackgroundImage(url)
                        }
                    } label: {
                        Image(systemName: "photo")
                    }
                    Button {
                        removeBackgroundImage()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct VCamMainToolbarPhotoPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarPhotoPicker(backgroundColor: .constant(.red), loadBackgroundImage: { _ in }, removeBackgroundImage: {})
    }
}
