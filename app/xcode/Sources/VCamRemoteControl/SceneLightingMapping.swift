import VCamEntity

/// Converts between the public lighting and the persisted one
enum SceneLightingMapping {
    static func lighting(_ lighting: SceneLighting) throws -> VCamScene.Lighting {
        for value in [lighting.azimuth, lighting.elevation, lighting.shadow] where !value.isFinite {
            throw TextStyleMapping.invalidParameter("lighting", "expected finite numbers")
        }
        guard (0...1).contains(lighting.shadow) else {
            throw TextStyleMapping.invalidParameter("shadow", "expected a number from 0 to 1")
        }
        return VCamScene.Lighting(
            azimuth: Float(lighting.azimuth),
            elevation: Float(lighting.elevation),
            shadow: Float(lighting.shadow),
            shadowColor: try TextStyleMapping.color(lighting.shadowColor),
            rim: try lighting.rim.map { rim in
                guard rim.intensity.isFinite, rim.intensity >= 0 else {
                    throw TextStyleMapping.invalidParameter("intensity", "expected a non-negative number")
                }
                return .init(color: try TextStyleMapping.color(rim.color), intensity: Float(rim.intensity))
            }
        )
    }

    static func apiLighting(_ lighting: VCamScene.Lighting) -> SceneLighting {
        SceneLighting(
            azimuth: Double(lighting.azimuth),
            elevation: Double(lighting.elevation),
            rim: lighting.rim.map { SceneLightingRim(color: TextStyleMapping.hex($0.color), intensity: Double($0.intensity)) },
            shadow: Double(lighting.shadow),
            shadowColor: TextStyleMapping.hex(lighting.shadowColor)
        )
    }
}
