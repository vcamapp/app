import Foundation
import CoreImage
import AppKit
import VCamEntity

public final class ImageRenderer: StaticImageRenderer {
    public convenience init(imageURL url: URL, filter: ImageFilter?) {
        let image = CIImage(contentsOf: url) ?? .empty()
        self.init(image: image, filter: filter)
    }

    public override init(image: CIImage, filter: ImageFilter?) {
        super.init(image: image, filter: filter)
    }
}
