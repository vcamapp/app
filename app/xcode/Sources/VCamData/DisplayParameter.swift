import Foundation
import VCamLogger
import VCamEntity
import SwiftUI
import AppKit

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

    public struct Color: Codable, Equatable, Sendable {
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

    public init(name: String = "", id: String = UUID().uuidString, value: Value = Value()) {
        self.name = name
        self.id = id
        self.value = value
    }
}

private struct DisplayParameterPresetsFile: Codable {
    var parameters: [DisplayParameter]
}

@MainActor
@Observable
public final class DisplayParameterPresets {
    public static let shared = DisplayParameterPresets()

    public private(set) var parameters: [DisplayParameter] = []
    private(set) var isLoadFailed = false
    public var currentParameterId: String?

    public var currentParameter: DisplayParameter? {
        guard let currentParameterId else { return nil }
        return parameters.find(byId: currentParameterId)
    }

    private static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "tattn/VCam/dparam")
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            parameters = [DisplayParameter()]
            isLoadFailed = false
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(DisplayParameterPresetsFile.self, from: data)
            parameters = file.parameters.isEmpty ? [DisplayParameter()] : file.parameters
            isLoadFailed = false
        } catch {
            parameters = [DisplayParameter()]
            isLoadFailed = true
            Logger.error(error)
        }
    }

    public func updateCurrentParameterName(_ name: String) {
        update { parameters, currentParameterId in
            guard let currentParameterId,
                  let index = parameters.index(ofId: currentParameterId) else { return }
            parameters[index].name = name
        }
    }

    public func saveCurrentParameterValue(_ value: DisplayParameter.Value) {
        update { parameters, currentParameterId in
            guard let currentParameterId,
                  let index = parameters.index(ofId: currentParameterId) else { return }
            parameters[index].value = value
        }
    }

    public func addParameter() -> DisplayParameter? {
        let newParam = DisplayParameter()
        guard update({ parameters, currentParameterId in
            parameters.append(newParam)
            currentParameterId = newParam.id
        }) else { return nil }
        return newParam
    }

    public func deleteCurrentParameter() {
        update { parameters, currentParameterId in
            guard let selectedParameterId = currentParameterId,
                  let index = parameters.index(ofId: selectedParameterId),
                  parameters.count > 1 else { return }
            parameters.remove(at: index)
            currentParameterId = parameters[min(index, parameters.count - 1)].id
        }
    }

    @discardableResult
    private func update(_ transform: (inout [DisplayParameter], inout String?) -> Void) -> Bool {
        guard prepareForWriting() else { return false }

        do {
            var newParameters = parameters
            var newCurrentParameterId = currentParameterId
            transform(&newParameters, &newCurrentParameterId)
            guard newParameters != parameters || newCurrentParameterId != currentParameterId else { return true }
            try save(newParameters)
            parameters = newParameters
            currentParameterId = newCurrentParameterId
            return true
        } catch {
            Logger.error(error)
            return false
        }
    }

    private func prepareForWriting() -> Bool {
        guard isLoadFailed else { return true }
        load()
        return !isLoadFailed
    }

    private func save(_ parameters: [DisplayParameter]) throws {
        let file = DisplayParameterPresetsFile(parameters: parameters)
        let data = try JSONEncoder().encode(file)
        try FileManager.default.createDirectoryIfNeeded(at: fileURL.deletingLastPathComponent())
        try data.write(to: fileURL, options: .atomic)
    }
}
