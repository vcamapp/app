import ScreenCaptureKit
import Synchronization
import VCamBridge
import VCamEntity

@MainActor
@Observable
public final class ScreenRecorder: NSObject {
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
            capturesVideo: Bool = true,
            capturesAudio: Bool = false,
            minimumFrameInterval: CMTime? = nil
        ) {
            self.captureType = captureType
            self.display = display
            self.window = window
            self.filterOutOwningApplication = filterOutOwningApplication
            self.capturesVideo = capturesVideo
            self.capturesAudio = capturesAudio
            self.minimumFrameInterval = minimumFrameInterval
        }

        public var captureType: CaptureType = .display
        public var display: SCDisplay?
        public var window: SCWindow?
        public var filterOutOwningApplication = true
        public var capturesVideo = true
        public var capturesAudio = false
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

    struct CapturedFrame: @unchecked Sendable {
        // surfaceRef is unretained, so keep the sample buffer to extend the IOSurface's lifetime
        let retainedSampleBuffer: CMSampleBuffer
        var surfaceRef: IOSurfaceRef
        var contentRect: CGRect
        var scaleFactor: Double

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

    @ObservationIgnored private var didVideoOutput: (@MainActor (CapturedFrame) -> Void)?
    @ObservationIgnored private var didAudioOutput: ((CMSampleBuffer) -> Void)?

    // Stale frames have no value for rendering, so only the newest one is kept
    // while a MainActor hop is pending; this also caps the number of in-flight tasks at one
    private let pendingVideoFrame = Mutex<CapturedFrame?>(nil)

    @MainActor
    @ObservationIgnored public var size: CGSize {
        guard let config = captureConfig else {
            return .init(width: 1024, height: 640)
        }
        if config.captureType == .display, let display = config.display {
            // SCDisplay's width/height are in points; match the pixel size requested in streamConfiguration
            return .init(width: display.width * 2, height: display.height * 2)
        } else if let window = config.window {
            let scale = NSApp.window(withWindowNumber: Int(window.windowID))?.backingScaleFactor ?? 2
            let frame = window.frame
            return .init(width: Int(frame.width * scale), height: Int(frame.height * scale))
        }
        return .init(width: 1024, height: 640)
    }

    @ObservationIgnored public var cropRect = CGRect(x: 0, y: 0, width: 1024, height: 640)

    @ObservationIgnored public var filter: ImageFilter?

    @MainActor private(set) var latestFrame: CapturedFrame?
    @MainActor private(set) var error: (any Error)?
    @MainActor private(set) var isRecording = false

    @ObservationIgnored public private(set) var captureConfig: CaptureConfiguration?
    @ObservationIgnored private var stream: SCStream?
    private let videoSampleBufferQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.screenrecorder.video")
    private let audioSampleBufferQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.screenrecorder.audio")

    @MainActor
    public func startCapture(with captureConfig: CaptureConfiguration) async throws {
        error = nil
        isRecording = false
        self.captureConfig = captureConfig

        do {
            // Create the content filter with the sample app settings.
            let filter = try await contentFilter(for: captureConfig)

            // Create the stream configuration with the sample app settings.
            let streamConfig = streamConfiguration(for: captureConfig)

            // Create a capture stream with the filter and stream configuration.
            let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
            self.stream = stream

            if captureConfig.capturesVideo {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            }
            if captureConfig.capturesAudio {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            }

            // Start the capture session.
            try await stream.startCapture()

            isRecording = true
        } catch {
            uniDebugLog("ScreenCapture error: \(error)")
            self.error = error
            try? await stream?.stopCapture()
            stream = nil
            throw error
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

    @MainActor
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

    @MainActor
    private func streamConfiguration(for captureConfig: CaptureConfiguration) -> SCStreamConfiguration {
        let streamConfig = SCStreamConfiguration()

        streamConfig.capturesAudio = captureConfig.capturesAudio
        streamConfig.sampleRate = 48000
        streamConfig.channelCount = 1
//            streamConfig.excludesCurrentProcessAudio = isAppAudioExcluded // if excludes

        streamConfig.minimumFrameInterval =
            captureConfig.minimumFrameInterval
            ?? CMTime(value: 1, timescale: CMTimeScale(60))

        // Set the capture size to twice the display size to support retina displays.
        if let display = captureConfig.display, captureConfig.captureType == .display {
            streamConfig.width = display.width * 2
            streamConfig.height = display.height * 2
        }

        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5

        return streamConfig
    }

}

extension ScreenRecorder: SCStreamOutput {
    nonisolated
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else {
            return
        }

        if type == .screen {
            guard let frame = createCapturedFrame(for: sampleBuffer) else {
                return
            }
            let isFirstPendingFrame = pendingVideoFrame.withLock { pending in
                let isFirst = pending == nil
                pending = frame
                return isFirst
            }
            // A task is already scheduled; it will pick up the replaced frame
            guard isFirstPendingFrame else { return }
            Task { @MainActor in
                guard let frame = pendingVideoFrame.withLock({ pending -> CapturedFrame? in
                    defer { pending = nil }
                    return pending
                }) else { return }
                latestFrame = frame
                didVideoOutput?(frame)
            }
        } else if type == .audio {
            Task { @MainActor in
                self.didAudioOutput?(sampleBuffer)
            }
        }
    }

    nonisolated private func createCapturedFrame(for sampleBuffer: CMSampleBuffer) -> CapturedFrame? {
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

        guard let contentRectDict = attachments[.contentRect] as? NSDictionary,
              let contentRect = CGRect(dictionaryRepresentation: contentRectDict as CFDictionary) else {
            return nil
        }

        guard let scaleFactor = attachments[.scaleFactor] as? Double else {
            return nil
        }

        return CapturedFrame(retainedSampleBuffer: sampleBuffer,
                             surfaceRef: surfaceRef,
                             contentRect: contentRect,
                             scaleFactor: scaleFactor)
    }
}

extension ScreenRecorder: SCStreamDelegate {
    nonisolated
    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            self.error = error
            self.isRecording = false
        }
    }
}

extension ScreenRecorder: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        didVideoOutput = { [weak self] frame in
            guard let self = self else { return }
            var image = frame.croppedCIImage
            image = filter?.apply(to: image) ?? image
            updator(image)
        }
        Task {
            await refreshScreen() // Call this because if not updated, the screen may become transparent when added.
        }
    }

    public func snapshot() async -> CIImage {
        let frame = latestFrame
        guard let frame else { return .init() }
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
            // Failures are kept in self.error for the UI
            try? await startCapture(with: captureConfig)
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
    // Use the main thread for size since the Unity side's Canvas size is required
    @MainActor
    static func create(id: String, screenCapture: VCamScene.ScreenCapture) async throws -> ScreenRecorder {
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
        try await screenRecorder.startCapture(with: configuration)
        uniDebugLog("ScreenRecorder.create: \(screenRecorder)")
        return screenRecorder
    }

    static func audioOnly(output: @escaping (CMSampleBuffer) -> Void) -> ScreenRecorder {
        let audioCapture = ScreenRecorder()
        Task {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            let configuration = ScreenRecorder.CaptureConfiguration(
                captureType: .display,
                display: availableContent.displays.first, // If not set to display, sound will not be recorded.
                capturesVideo: false,
                capturesAudio: true,
                minimumFrameInterval: .init(value: 1, timescale: 10) // https://developer.apple.com/forums/thread/718279
            )
            try await audioCapture.startCapture(with: configuration)
        }
        audioCapture.didAudioOutput = { buffer in
            output(buffer)
        }
        return audioCapture
    }
}

extension SCDisplay: @retroactive Identifiable {
    public var id: String {
        return String(CGDisplaySerialNumber(displayID))
    }
}

extension SCWindow: @retroactive Identifiable  {
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

extension CMSampleBuffer: @retroactive @unchecked Sendable {}
