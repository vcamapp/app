//
//  ScreenRecorder.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import ScreenCaptureKit
import AVFAudio
import VCamBridge
import VCamEntity

public protocol ScreenRecorderProtocol: AnyObject {
    @MainActor func stopCapture() async
}

public final class ScreenRecorder: NSObject, ObservableObject, ScreenRecorderProtocol {
    public enum CaptureType {
        case independentWindow
        case display

        init(type: VCamScene.ScreenCapture.CaptureType) {
            switch type {
            case .window: self = .independentWindow
            case .display: self = .display
            }
        }
    }

    public struct CaptureConfiguration {
        public init(
            captureType: ScreenRecorder.CaptureType = .display,
            display: SCDisplay? = nil,
            window: SCWindow? = nil,
            filterOutOwningApplication: Bool = true,
            capturesAudio: Bool = true,
            minimumFrameInterval: CMTime? = nil
        ) {
            self.captureType = captureType
            self.display = display
            self.window = window
            self.filterOutOwningApplication = filterOutOwningApplication
            self.capturesAudio = capturesAudio
            self.minimumFrameInterval = minimumFrameInterval
        }

        public var captureType: CaptureType = .display
        public var display: SCDisplay?
        public var window: SCWindow?
        public var filterOutOwningApplication = true
        public var capturesAudio = true
        public var minimumFrameInterval: CMTime?

        public var id: String? {
            switch captureType {
            case .independentWindow:
                return window?.id
            case .display:
                return display?.id
            }
        }
    }

    struct CapturedFrame {
        var sampleBuffer: CMSampleBuffer
        var surfaceRef: IOSurfaceRef
        var contentRect: CGRect
        var displayTime: TimeInterval
        var contentScale: Double
        var scaleFactor: Double
        var surface: IOSurface {
            // Force-cast the IOSurfaceRef to IOSurface.
            return unsafeBitCast(surfaceRef, to: IOSurface.self)
        }

        var croppedCIImage: CIImage {
            CIImage(ioSurface: surfaceRef).cropped(to: contentRect.applying(.init(scaleX: scaleFactor, y: scaleFactor)))
        }
    }

    struct ScreenRecorderError: Error {
        let errorDescription: String

        init(_ description: String) {
            errorDescription = description
        }
    }

    private var didVideoOutput: ((CapturedFrame) -> Void)?
    private var didAudioOutput: ((CMSampleBuffer) -> Void)?

    public var size: CGSize {
        guard let config = captureConfig else {
            return .init(width: 1024, height: 640)
        }
        if config.captureType == .display, let display = config.display {
            let size = CGDisplayScreenSize(display.displayID)
            return .init(width: Int(size.width), height: Int(size.height))
        } else if let window = config.window {
            let scale = NSApp.window(withWindowNumber: Int(window.windowID))?.backingScaleFactor ?? 2
            let frame = window.frame
            return .init(width: Int(frame.width * scale), height: Int(frame.height * scale))
        }
        return .init(width: 1024, height: 640)
    }

    public var cropRect = CGRect(x: 0, y: 0, width: 1024, height: 640)

    public var filter: ImageFilter?

    @MainActor @Published private(set) var latestFrame: CapturedFrame?
    @MainActor @Published private(set) var error: (any Error)?
    @MainActor @Published private(set) var isRecording = false

    public private(set) var captureConfig: CaptureConfiguration?
    private var stream: SCStream?
    private var cpuStartTime = mach_absolute_time()
    private var mediaStartTime = CACurrentMediaTime()
    private let videoSampleBufferQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.screenrecorder.video")
    private let audioSampleBufferQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.screenrecorder.audio")

    @MainActor
    public func startCapture(with captureConfig: CaptureConfiguration) async {
        error = nil
        isRecording = false
        self.captureConfig = captureConfig

        do {
            // Create the content filter with the sample app settings.
            let filter = try await contentFilter(for: captureConfig)

            // Create the stream configuration with the sample app settings.
            let streamConfig = streamConfiguration(for: captureConfig)

            // Create a capture stream with the filter and stream configuration.
            stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)

            // Add a stream output to capture screen content.
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            if captureConfig.capturesAudio {
                try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            }

            // Start the capture session.
            try await stream?.startCapture()

            cpuStartTime = mach_absolute_time()
            mediaStartTime = CACurrentMediaTime()
            isRecording = true

            await update(with: captureConfig)
        } catch {
            uniDebugLog("ScreenCapture error: \(error)")
            self.error = error
        }
    }

    @MainActor
    public func update(with captureConfig: CaptureConfiguration) async {
        do {
            self.captureConfig = captureConfig
            let filter = try await contentFilter(for: captureConfig)
            let streamConfig = streamConfiguration(for: captureConfig)
            try await stream?.updateConfiguration(streamConfig)
            try await stream?.updateContentFilter(filter)
        } catch {
            self.error = error
        }
    }

    @MainActor
    func refreshScreen() async {
        try? await stream?.stopCapture()
        try? await stream?.startCapture()
    }

    @MainActor
    public func stopCapture() async {
        isRecording = false

        do {
            try await stream?.stopCapture()
        } catch {
            self.error = error
        }
    }

    private func contentFilter(for config: CaptureConfiguration) async throws -> SCContentFilter {
        switch config.captureType {
        case .display:
            if let display = config.display {

                // Create a content filter that includes all content from the display,
                // excluding the sample app's window.
                if config.filterOutOwningApplication {

                    // Get the content that's available to capture.
                    let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                       onScreenWindowsOnly: true)

                    // Exclude the sample app by matching the bundle identifier.
                    let excludedApps = content.applications.filter { app in
                        Bundle.main.bundleIdentifier == app.bundleIdentifier
                    }

                    // Create a content filter that excludes the sample app.
                    return SCContentFilter(display: display,
                                           excludingApplications: excludedApps,
                                           exceptingWindows: [])

                } else {
                    // Create a content filter that includes the entire display.
                    return SCContentFilter(display: display, excludingWindows: [])
                }
            }
        case .independentWindow:
            if let window = config.window {

                // Create a content filter that includes a single window.
                return SCContentFilter(desktopIndependentWindow: window)

            }
        }
        throw ScreenRecorderError("The configuration doesn't provide a display or window.")
    }

    private func streamConfiguration(for captureConfig: CaptureConfiguration) -> SCStreamConfiguration {
        let streamConfig = SCStreamConfiguration()

        streamConfig.capturesAudio = captureConfig.capturesAudio
        streamConfig.sampleRate = 44100 // not working?
        streamConfig.channelCount = 1
//            streamConfig.excludesCurrentProcessAudio = isAppAudioExcluded // if excludes

        if let minimumFrameInterval = captureConfig.minimumFrameInterval {
            streamConfig.minimumFrameInterval = minimumFrameInterval
        }

        // Set the capture size to twice the display size to support retina displays.
        if let display = captureConfig.display, captureConfig.captureType == .display {
            streamConfig.width = display.width * 2
            streamConfig.height = display.height * 2
        }

        // Set the capture interval at 60 fps.
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(60))

        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5

        return streamConfig
    }

    private func convertToSeconds(_ machTime: UInt64) -> TimeInterval {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nanoseconds = machTime * UInt64(timebase.numer) / UInt64(timebase.denom)
        return Double(nanoseconds) / Double(kSecondScale)
    }
}

extension ScreenRecorder: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else {
            return
        }

        if type == .screen {
            guard let frame = createCapturedFrame(for: sampleBuffer) else {
                return
            }
            DispatchQueue.main.async {
                self.latestFrame = frame
                self.didVideoOutput?(frame)
            }
        } else if type == .audio {
//            guard let buffer = createPCMBuffer(for: sampleBuffer) else {
//                return
//            }
            DispatchQueue.main.async {
                self.didAudioOutput?(sampleBuffer)
            }
        }
    }

    private func createCapturedFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first else {
            return nil
        }

        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else {
            return nil
        }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            return nil
        }

        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            return nil
        }

        guard let contentRectDict = attachments[.contentRect],
              let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary) else {
            return nil
        }

        guard let displayTime = attachments[.displayTime] as? UInt64 else {
            return nil
        }

        let elapsedTime = convertToSeconds(displayTime) - convertToSeconds(cpuStartTime)

        guard let contentScale = attachments[.contentScale] as? Double,
              let scaleFactor = attachments[.scaleFactor] as? Double else {
            return nil
        }

        return CapturedFrame(sampleBuffer: sampleBuffer,
                             surfaceRef: surfaceRef,
                             contentRect: contentRect,
                             displayTime: elapsedTime,
                             contentScale: contentScale,
                             scaleFactor: scaleFactor)
    }

    private func createPCMBuffer(for sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        var ablPointer: UnsafePointer<AudioBufferList>?
        try? sampleBuffer.withAudioBufferList(flags: .audioBufferListAssure16ByteAlignment) { audioBufferList, blockBuffer in
            ablPointer = audioBufferList.unsafePointer
        }
        guard let audioBufferList = ablPointer,
              let absd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame) else { return nil }
        return AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList)
    }
}

extension ScreenRecorder: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        DispatchQueue.main.async {
            self.error = error
            self.isRecording = false
        }
    }
}

extension ScreenRecorder: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        didVideoOutput = { [weak self] frame in
            guard let self = self else { return }
            DispatchQueue.main.async {
                var image = frame.croppedCIImage
                image = self.filter?.apply(to: image) ?? image
                updator(image)
            }
        }
        Task {
            await refreshScreen() // Call this because if not updated, the screen may become transparent when added.
        }
    }

    @MainActor
    public func snapshot() -> CIImage {
        guard let frame = latestFrame else { return .init() }
        return frame.croppedCIImage
    }

    public func disableRenderTexture() {
        didVideoOutput = nil
    }

    public func pauseRendering() {
        Task {
            await stopCapture()
        }
    }

    public func resumeRendering() {
        guard let captureConfig = captureConfig else { return }
        Task {
            await startCapture(with: captureConfig)
        }
    }

    public func stopRendering() {
        didVideoOutput = nil
        Task {
            await stopCapture()
        }
    }
}

public extension ScreenRecorder {
    static func create(id: String, screenCapture: VCamScene.ScreenCapture, completion: @escaping (ScreenRecorder) -> Void) {
        Task { @MainActor in // Use the main thread for size since the Unity side's Canvas size is required
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            uniDebugLog("ScreenRecorder.create: \(availableContent)")
            let configuration = CaptureConfiguration(
                captureType: .init(type: screenCapture.captureType),
                display: availableContent.displays.first { $0.id == id },
                window: availableContent.windows.first { $0.id == id }
            )

            let screenRecorder = ScreenRecorder()
            screenRecorder.cropRect = screenCapture.texture.crop.rect
            screenRecorder.filter = screenCapture.texture.filter.map(ImageFilter.init(configuration:))
            await screenRecorder.startCapture(with: configuration)
            uniDebugLog("ScreenRecorder.create: \(screenRecorder)")
            completion(screenRecorder)
        }
    }

    static func audioOnly(output: @escaping (CMSampleBuffer, CFTimeInterval) -> Void) -> ScreenRecorder {
        let audioCapture = ScreenRecorder()
        Task {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            let configuration = ScreenRecorder.CaptureConfiguration(
                captureType: .display,
                display: availableContent.displays.first, // If not set to display, sound will not be recorded.
                minimumFrameInterval: .init(value: 1, timescale: 10) // https://developer.apple.com/forums/thread/718279
            )
            await audioCapture.startCapture(with: configuration)
        }
        let mediaStartTime = audioCapture.mediaStartTime
        audioCapture.didAudioOutput = { buffer in
            output(buffer, mediaStartTime)
        }
        return audioCapture
    }
}

extension SCDisplay: Identifiable {
    public var id: String {
        return String(CGDisplaySerialNumber(displayID))
    }
}

extension SCWindow: Identifiable  {
    public var id: String {
        guard let infoList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [NSDictionary],
              let info = infoList.first,
              let ownerName = info[kCGWindowOwnerName] as? String,
              let title = info[kCGWindowName] as? String else {
            return ""
        }
        return "\(ownerName)-\(title)"
    }
}

public extension ScreenRecorder.CaptureType {
    var type: VCamScene.ScreenCapture.CaptureType {
        switch self {
        case .independentWindow: return .window
        case .display: return .display
        }
    }
}
