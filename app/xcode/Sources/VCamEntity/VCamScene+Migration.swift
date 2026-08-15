import Foundation

public extension VCamScene {
    /// Scene format history:
    /// - 1 (`version == nil`): crop rects normalized every component by the texture width,
    ///   so `height` could exceed 1 (e.g. 0.5625 for an uncropped 16:9 texture).
    /// - 2: crop rects are unit rects; (0, 0, 1, 1) is always the whole texture.
    static let currentVersion = 2

    /// Migrates a decoded scene to the current format in memory.
    /// The migrated form reaches the disk only through the next regular save.
    mutating func migrateToCurrentVersion() {
        if version == nil {
            migrateCropToUnitRect()
        }
        version = Self.currentVersion
    }

    private mutating func migrateCropToUnitRect() {
        for index in objects.indices {
            switch objects[index].type {
            case let .screen(id, state):
                var state = state
                state.texture.migrateCropToUnitRect()
                objects[index].type = .screen(id: id, state: state)
            case let .captureDevice(id, state):
                var state = state
                state.migrateCropToUnitRect()
                objects[index].type = .captureDevice(id: id, state: state)
            case let .web(state):
                var state = state
                // Web textures always render the whole page, and version 1 stored them
                // normalized by the longer side instead, so reset rather than convert
                state.texture.crop = .init(x: 0, y: 0, width: 1, height: 1)
                objects[index].type = .web(state: state)
            case .avatar, .image, .text, .wind:
                break
            }
        }
    }
}

private extension VCamScene.RenderTexture {
    mutating func migrateCropToUnitRect() {
        guard height > 0 else { return }
        let scale = width / height
        crop.y *= scale
        crop.height *= scale
    }
}
