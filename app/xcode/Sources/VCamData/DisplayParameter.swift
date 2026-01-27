import Foundation
import SwiftUI
import AppKit
import VCamLocalization

public struct DisplayParameter: Codable, Identifiable, Equatable {
    public struct Value: Codable, Equatable {
        public var light: Float = 0.9
        public var environmentLightColor: DisplayParameter.Color = .white
        public var postExposure: Float = 0
        public var colorFilter: DisplayParameter.Color = .white
        public var saturation: Float = 0
        public var hueShift: Float = 0
        public var contrast: Float = 0
        public var whiteBalanceTemperature: Float = 0
        public var whiteBalanceTint: Float = 0
        public var bloomIntensity: Float = 4.5
        public var bloomThreshold: Float = 1
        public var bloomSoftKnee: Float = 0.5
        public var bloomDiffusion: Float = 7
        public var bloomAnamorphicRatio: Float = 0
        public var bloomColor: DisplayParameter.Color = .white
        public var bloomLensFlare: Int = 0
        public var bloomLensFlareIntensity: Float = 0
        public var vignetteIntensity: Float = 0
        public var vignetteColor: DisplayParameter.Color = .black
        public var vignetteSmoothness: Float = 0.2
        public var vignetteRoundness: Float = 1

        public init() {}
    }

    public struct Color: Codable, Equatable {
        public var r: Float
        public var g: Float
        public var b: Float
        public var a: Float

        public static let white = Color(r: 1, g: 1, b: 1, a: 1)
        public static let black = Color(r: 0, g: 0, b: 0, a: 1)

        public init(r: Float, g: Float, b: Float, a: Float = 1) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }

        public init(from color: SwiftUI.Color) {
            guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else {
                self = .white
                return
            }
            self.r = Float(nsColor.redComponent)
            self.g = Float(nsColor.greenComponent)
            self.b = Float(nsColor.blueComponent)
            self.a = Float(nsColor.alphaComponent)
        }

        public var swiftUIColor: SwiftUI.Color {
            SwiftUI.Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
        }
    }

    public var name: String
    public let id: String
    public var value: Value

    public init(name: String = L10n.newPreset.text, id: String = UUID().uuidString, value: Value = Value()) {
        self.name = name
        self.id = id
        self.value = value
    }
}

private struct DisplayParameterPresetsFile: Codable {
    var parameters: [DisplayParameter]
}

@Observable
public final class DisplayParameterPresets {
    public static let shared = DisplayParameterPresets()

    public private(set) var parameters: [DisplayParameter] = []
    public var currentParameterId: String?

    public var currentParameter: DisplayParameter? {
        guard let currentParameterId else { return nil }
        return parameters.first { $0.id == currentParameterId }
    }

    public var currentParameterIndex: Int? {
        guard let currentParameterId else { return nil }
        return parameters.firstIndex { $0.id == currentParameterId }
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "tattn/VCam/dparam")
    }

    private init() {
        load()
    }

    public func load() {
        do {
            let data = try Data(contentsOf: Self.fileURL)
            let file = try JSONDecoder().decode(DisplayParameterPresetsFile.self, from: data)
            parameters = file.parameters.isEmpty ? [DisplayParameter()] : file.parameters
        } catch {
            // File doesn't exist or decoding failed - use default
            parameters = [DisplayParameter()]
        }
    }

    public func save() {
        do {
            let file = DisplayParameterPresetsFile(parameters: parameters)
            let data = try JSONEncoder().encode(file)
            let directory = Self.fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectoryIfNeeded(at: directory)
            try data.write(to: Self.fileURL)
        } catch {
            print("Failed to save display parameters: \(error)")
        }
    }

    public func updateCurrentParameterName(_ name: String) {
        guard let index = currentParameterIndex else { return }
        parameters[index].name = name
        save()
    }

    public func saveCurrentParameterValue(_ value: DisplayParameter.Value) {
        guard let index = currentParameterIndex else { return }
        parameters[index].value = value
        save()
    }

    public func addParameter() -> DisplayParameter {
        let newParam = DisplayParameter()
        parameters.append(newParam)
        currentParameterId = newParam.id
        save()
        return newParam
    }

    public func deleteCurrentParameter() {
        guard let index = currentParameterIndex, parameters.count > 1 else { return }
        parameters.remove(at: index)
        // Select next or previous
        let newIndex = min(index, parameters.count - 1)
        currentParameterId = parameters[newIndex].id
        save()
    }
}

// MARK: - DisplayParameterPreset (for UI compatibility)

public struct DisplayParameterPreset: CaseIterable, Hashable, Identifiable, CustomStringConvertible {
    public static var allCases: [DisplayParameterPreset] {
        DisplayParameterPresets.shared.parameters.map {
            DisplayParameterPreset(id: $0.id, description: $0.name)
        }
    }

    public static let newPreset = Self.init(id: "", description: L10n.newPreset.text)

    public let id: String
    public var description: String

    public init(id: String, description: String) {
        self.id = id
        self.description = description
    }
}
