import Foundation

/// One line of a tracking trace. Every timestamp is `ProcessInfo.systemUptime` in seconds
/// so the stages can be laid on the same axis; `Meta.startUptime` rebases them to zero.
public enum TrackingTraceRecord {
    /// A datagram as it left the receive queue, before the hop to the main actor.
    public struct Datagram: Codable, Sendable, Equatable {
        public var t: Double
        /// Receive order, shared with `MainArrival.n` and `Push.n`
        public var n: Int
        public var length: Int
        /// 0 for the legacy layout, 1 for the framed protocol, nil for anything else
        public var version: Int?
        public var type: String?
        public var sessionID: UInt32?
        public var sequence: UInt32?
        /// The sender's clock in nanoseconds; only the framed protocol carries it
        public var senderTimestamp: UInt64?
        /// Base64 payload, kept so the trace can be replayed
        public var payload: String

        public init(t: Double, n: Int, length: Int, version: Int?, type: String?, sessionID: UInt32?,
                    sequence: UInt32?, senderTimestamp: UInt64?, payload: String) {
            self.t = t
            self.n = n
            self.length = length
            self.version = version
            self.type = type
            self.sessionID = sessionID
            self.sequence = sequence
            self.senderTimestamp = senderTimestamp
            self.payload = payload
        }
    }

    public struct MainArrival: Codable, Sendable, Equatable {
        public var t: Double
        public var n: Int

        public init(t: Double, n: Int) {
            self.t = t
            self.n = n
        }
    }

    public struct Push: Codable, Sendable, Equatable {
        public var t: Double
        public var label: String
        /// The datagram this push came from, when it was pushed while handling one
        public var n: Int?
        public var values: [Float]

        public init(t: Double, label: String, n: Int?, values: [Float]) {
            self.t = t
            self.label = label
            self.n = n
            self.values = values
        }
    }

    public struct Sample: Codable, Sendable, Equatable {
        public var t: Double
        public var label: String
        public var renderTime: Double
        public var mode: TrackingResamplerSampling.Mode
        /// How many frame spans past the last frame the output was extrapolated
        public var factor: Float?
        /// Time between the two frames the extrapolation was based on
        public var spacing: Double?
        public var values: [Float]

        public init(t: Double, label: String, renderTime: Double, mode: TrackingResamplerSampling.Mode,
                    factor: Float?, spacing: Double?, values: [Float]) {
            self.t = t
            self.label = label
            self.renderTime = renderTime
            self.mode = mode
            self.factor = factor
            self.spacing = spacing
            self.values = values
        }
    }

    /// What the engine applied in a frame. The layout is shared with the engines that fill it
    /// (`TrackingTraceEngineValue`).
    public struct Engine: Codable, Sendable, Equatable {
        public var t: Double
        public var values: [Float]

        public init(t: Double, values: [Float]) {
            self.t = t
            self.values = values
        }

        public subscript(_ value: TrackingTraceEngineValue) -> Float? {
            values.indices.contains(value.rawValue) ? values[value.rawValue] : nil
        }
    }

    public struct Event: Codable, Sendable, Equatable {
        public var t: Double
        public var name: String
        public var info: [String: String]

        public init(t: Double, name: String, info: [String: String] = [:]) {
            self.t = t
            self.name = name
            self.info = info
        }
    }

    public struct Meta: Codable, Sendable, Equatable {
        public var app: String
        public var version: String
        public var os: String
        public var machine: String
        public var startedAt: Date
        public var startUptime: Double
        public var faceTrackingMethod: String
        public var handTrackingMethod: String
        public var fingerTrackingMethod: String
        public var motionProtocol: String?
        public var mocapNetworkInterpolation: Double
        public var trackingSmoothing: Double
        public var bodyFollowWeight: Double
        public var mirrorsTracking: Bool
        public var mappings: TrackingMappingsSnapshot
        public var extra: [String: String]

        public init(app: String, version: String, os: String, machine: String, startedAt: Date, startUptime: Double,
                    faceTrackingMethod: String, handTrackingMethod: String, fingerTrackingMethod: String,
                    motionProtocol: String?, mocapNetworkInterpolation: Double, trackingSmoothing: Double,
                    bodyFollowWeight: Double, mirrorsTracking: Bool, mappings: TrackingMappingsSnapshot,
                    extra: [String: String] = [:]) {
            self.app = app
            self.version = version
            self.os = os
            self.machine = machine
            self.startedAt = startedAt
            self.startUptime = startUptime
            self.faceTrackingMethod = faceTrackingMethod
            self.handTrackingMethod = handTrackingMethod
            self.fingerTrackingMethod = fingerTrackingMethod
            self.motionProtocol = motionProtocol
            self.mocapNetworkInterpolation = mocapNetworkInterpolation
            self.trackingSmoothing = trackingSmoothing
            self.bodyFollowWeight = bodyFollowWeight
            self.mirrorsTracking = mirrorsTracking
            self.mappings = mappings
            self.extra = extra
        }
    }

    public struct TrackingMappingsSnapshot: Codable, Sendable, Equatable {
        public var blendShape: [TrackingMappingEntry]
        public var perfectSync: [TrackingMappingEntry]

        public init(blendShape: [TrackingMappingEntry], perfectSync: [TrackingMappingEntry]) {
            self.blendShape = blendShape
            self.perfectSync = perfectSync
        }
    }
}

/// Positions in `TrackingTraceRecord.Engine.values`. Angles are degrees before the engine's
/// clamp, positions are meters in the avatar's root space.
public enum TrackingTraceEngineValue: Int, CaseIterable, Sendable {
    case headPitch = 0
    case headYaw
    case headRoll
    case positionX
    case positionY
    case positionZ
    case bodyFollowWeight
    case pelvisOffsetX
    case pelvisOffsetY
    case pelvisOffsetZ
    case pelvisYaw
    /// 1 while a motion owns the body (VRMA or built-in playback), 0 while tracking does
    case motionOwnsBody

    public static let count = allCases.count
}

/// The leading channels of a face stream (`FaceTransformValues.headPoseValues`), which the
/// analysis and the report read by index
public enum TrackingTraceFaceValue: Int, Sendable {
    case positionX = 0
    case positionY
    case positionZ
    case headPitch
    case headYaw
    case headRoll

    public static let position = positionX.rawValue...positionZ.rawValue
    public static let head = headPitch.rawValue...headRoll.rawValue

    /// Whether a resampler label carries a face stream rather than hands or fingers
    public static func isFaceLabel(_ label: String) -> Bool {
        label.hasSuffix("blendshape") || label.hasSuffix("perfectsync")
    }
}

/// File names inside a trace directory
public enum TrackingTraceFile: String, CaseIterable, Sendable {
    case meta = "meta.json"
    case datagrams = "net.jsonl"
    case mainArrivals = "main.jsonl"
    case pushes = "resampler-push.jsonl"
    case samples = "resampler-tick.jsonl"
    case engine = "engine.jsonl"
    case events = "events.jsonl"
}
