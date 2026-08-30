import CoreGraphics

public extension CGSize {
    mutating func scaleToFit(size: CGSize) {
        guard width > 0, height > 0, size.width > 0, size.height > 0,
              width.isFinite, height.isFinite, size.width.isFinite, size.height.isFinite else { return }
        let scale = min(width / size.width, height / size.height)
        self = CGSize(width: size.width * scale, height: size.height * scale)
    }
}
