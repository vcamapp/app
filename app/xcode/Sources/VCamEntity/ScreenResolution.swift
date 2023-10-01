//
//  ScreenResolution.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/22.
//

import AVFoundation

public enum ScreenResolution: Identifiable, CaseIterable {
//    case resolution4320p
    case resolution2160p
//    case resolution1440p
    case resolution1080p
    case resolution720p
    case resolution540p
    case resolutionVertical1080p

    public var id: Self { self }

    public var size: (width: Int, height: Int) {
        switch self {
//        case .resolution4320p:
//            return (7680, 4320)
        case .resolution2160p:
            return (3840, 2160)
//        case .resolution1440p:
//            return (2560, 1440)
        case .resolution1080p:
            return (1920, 1080)
        case .resolution720p:
            return (1280, 720)
        case .resolution540p:
            return (960, 540)
        case .resolutionVertical1080p:
            return (1080, 1920)
        }
    }

    public var isLandscape: Bool {
        let size = size
        return size.width > size.height
    }

    public init(width: Int, height: Int) {
        for resolution in Self.allCases
        where resolution.size.width == width && resolution.size.height == height {
            self = resolution
            return
        }
        self = .resolution1080p
    }
}

public extension ScreenResolution {
    func videoOutputSettings(format: VideoFormat) -> [String: Any]? {
        switch self {
        case .resolution2160p:
            if format.isHevc {
                return AVOutputSettingsAssistant(preset: .hevc3840x2160WithAlpha)?.videoSettings
            } else {
                return AVOutputSettingsAssistant(preset: .preset3840x2160)?.videoSettings
            }
        case .resolution1080p:
            if format.isHevc {
                return AVOutputSettingsAssistant(preset: .hevc1920x1080WithAlpha)?.videoSettings
            } else {
                return AVOutputSettingsAssistant(preset: .preset1920x1080)?.videoSettings
            }
        case .resolution720p:
            if format.isHevc {
                return AVOutputSettingsAssistant.videoSettingsForHevc1280x720WithAlpha
            } else {
                return AVOutputSettingsAssistant(preset: .preset1280x720)?.videoSettings
            }
        case .resolution540p:
            if format.isHevc {
                return AVOutputSettingsAssistant.videoSettingsForHevc960x540WithAlpha
            } else {
                return AVOutputSettingsAssistant(preset: .preset960x540)?.videoSettings
            }
        case .resolutionVertical1080p:
            var compressionProperties: [String: Any] = [
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoAverageBitRateKey: 10485760,
                AVVideoProfileLevelKey: format.isHevc ? "HEVC_Main_AutoLevel" : AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoAllowFrameReorderingKey: 1
            ]

            var settings: [String: Any] = [
                AVVideoWidthKey: 1080,
                AVVideoHeightKey: 1920,
                AVVideoCodecKey: format.isHevc ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.h264,
                AVVideoColorPropertiesKey: [
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                ],
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
                AVVideoEncoderSpecificationKey: [
                    "EnableHardwareAcceleratedVideoEncoder": 1
                ]
            ]

            if format.isHevc {
                compressionProperties["TargetQualityForAlpha"] = 0.75
            } else {
                compressionProperties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
            }

            settings[AVVideoCompressionPropertiesKey] = compressionProperties
            return settings
        }
    }
}

extension AVOutputSettingsAssistant {
    public static var videoSettingsForHevc1280x720WithAlpha: [String : Any]? {
        videoSettingsForHevcWithAlpha(width: 1280, height: 720)
    }

    public static var videoSettingsForHevc960x540WithAlpha: [String : Any]? {
        videoSettingsForHevcWithAlpha(width: 960, height: 540)
    }

    private static func videoSettingsForHevcWithAlpha(width: Int, height: Int) -> [String : Any]? {
        guard var preset = AVOutputSettingsAssistant(preset: .hevc1920x1080WithAlpha)?.videoSettings else {
            return nil
        }
        preset[AVVideoWidthKey] = width
        preset[AVVideoHeightKey] = height
        return preset
    }
}
