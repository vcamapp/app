import Foundation
import CoreImage
import AVFoundation
import AppKit
import VCamEntity
import VCamMedia
import VCamTracking
import VCamLogger

public enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case finishing
}

private enum RecordingError: LocalizedError {
    case appendFailed(AVMediaType)
    case cannotAddInput(AVMediaType)
    case cannotStartWriting
    case cannotCreatePixelBuffer(CVReturn)

    var errorDescription: String? {
        switch self {
        case let .appendFailed(mediaType): "Failed to append \(mediaType.rawValue) media."
        case let .cannotAddInput(mediaType): "Failed to add the \(mediaType.rawValue) input."
        case .cannotStartWriting: "Failed to start writing."
        case let .cannotCreatePixelBuffer(status): "Failed to create a pixel buffer. (\(status))"
        }
    }
}

@MainActor
@Observable
public final class VideoRecorder { // TODO: Migrate new API for macOS 26+
    public static let shared = VideoRecorder()

    public private(set) var state: RecordingState = .idle
    public var isRecording: Bool {
        state == .recording
    }

    @ObservationIgnored private var assetwriter: AVAssetWriter?
    @ObservationIgnored private var assetVideoWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    @ObservationIgnored private var assetAudioWriterInput: AVAssetWriterInput?
    @ObservationIgnored private var assetPCAudioWriterInput: AVAssetWriterInput?

    @ObservationIgnored private var frameCount: Int64 = 0
    @ObservationIgnored private var startDate = Date()
    @ObservationIgnored private var sampleCount = CMTimeValue(0)
    @ObservationIgnored private var pcSampleCount = CMTimeValue(0)
    @ObservationIgnored private var baseHostTime = mach_absolute_time()
    private let context = CIContext(options: [.cacheIntermediates: false, .name: "VideoRecorder"])
    @ObservationIgnored private var outputURL: URL!
    @ObservationIgnored private var temporaryOutputURL: URL!

    @ObservationIgnored private var converter: AudioConverter?
    private let expectedFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    @ObservationIgnored private var systemAudioRecorder: ScreenRecorder?

#if DEBUG
    @ObservationIgnored private var debugTimer: Timer?
#endif

    public func start(with outputDirectory: URL, name: String, format: VideoFormat, screenResolution: ScreenResolution, capturesSystemAudio: Bool) throws {
        Logger.log("")
        guard case .idle = state else { return }
        state = .preparing
        do {
            try startRecording(with: outputDirectory, name: name, format: format, screenResolution: screenResolution, capturesSystemAudio: capturesSystemAudio)
        } catch {
            failRecording(error)
            throw error
        }
    }

    private func startRecording(with outputDirectory: URL, name: String, format: VideoFormat, screenResolution: ScreenResolution, capturesSystemAudio: Bool) throws {
        temporaryOutputURL = outputDirectory.appending(path: "\(name)_tmp.\(format.extension)")
        outputURL = outputDirectory.appending(path: "\(name).\(format.extension)")

        let assetwriter = try AVAssetWriter(outputURL: temporaryOutputURL, fileType: format.fileType)
        let outputSettings = screenResolution.videoOutputSettings(format: format)
        let assetVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        // Provide the attributes so that the adaptor exposes a pixel buffer pool;
        // rendering into a single reused buffer could corrupt frames the encoder still holds
        let assetVideoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetVideoWriterInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: screenResolution.size.width,
            kCVPixelBufferHeightKey as String: screenResolution.size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ])

        let assetAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 48000,
            AVEncoderBitRateKey: 128000
        ])

        let assetPCAudioWriterInput = capturesSystemAudio ? AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 48000,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]) : nil

        assetVideoWriterInput.expectsMediaDataInRealTime = true
        assetAudioWriterInput.expectsMediaDataInRealTime = true
        assetPCAudioWriterInput?.expectsMediaDataInRealTime = true

        guard assetwriter.canAdd(assetVideoWriterInput) else { throw RecordingError.cannotAddInput(.video) }
        assetwriter.add(assetVideoWriterInput)
        guard assetwriter.canAdd(assetAudioWriterInput) else { throw RecordingError.cannotAddInput(.audio) }
        assetwriter.add(assetAudioWriterInput)
        if let assetPCAudioWriterInput {
            guard assetwriter.canAdd(assetPCAudioWriterInput) else { throw RecordingError.cannotAddInput(.audio) }
            assetwriter.add(assetPCAudioWriterInput)
        }

        guard assetwriter.startWriting() else {
            throw assetwriter.error ?? RecordingError.cannotStartWriting
        }

        // Commit to the fields only after every step above has succeeded,
        // so a failed setup never leaves the recorder half-initialized in the recording state
        self.assetwriter = assetwriter
        self.assetVideoWriterAdaptor = assetVideoWriterAdaptor
        self.assetAudioWriterInput = assetAudioWriterInput
        self.assetPCAudioWriterInput = assetPCAudioWriterInput

        state = .recording
        frameCount = 0
        sampleCount = 0
        pcSampleCount = 0
        baseHostTime = mach_absolute_time()

        if capturesSystemAudio {
            systemAudioRecorder = ScreenRecorder.audioOnly { buffer in
                Task {
                    await Self.shared.renderPCAudioFrame(buffer)
                }
            }
        }

#if DEBUG
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { _ in
            Task { @MainActor in
                let debugImage = NSImage(color: .red, size: CGSize(width: 1920, height: 1080)).ciImage!
                Self.shared.renderFrame(debugImage)
            }
        }
#endif

        AvatarAudioManager.shared.start(usage: .record)
    }

    public func stop() {
        Logger.log("")
        switch state {
        case .recording:
            break
        case .idle, .preparing, .finishing:
            return
        }
        state = .finishing
#if DEBUG
        debugTimer?.invalidate()
        debugTimer = nil
#endif
        let audioOutputSettings = assetAudioWriterInput?.outputSettings as? [String: any Sendable] ?? [:]
        let capturedSystemAudio = assetPCAudioWriterInput != nil

        releaseWriterInputs()
        AvatarAudioManager.shared.stop(usage: .record)

        guard let assetwriter else {
            state = .idle
            return
        }

        Task { @MainActor in
            defer {
                try? FileManager.default.removeItem(at: temporaryOutputURL)
            }
            if let systemAudioRecorder {
                await systemAudioRecorder.stopCapture()
                self.systemAudioRecorder = nil
            }

            await assetwriter.finishWriting()
            self.assetwriter = nil

            do {
                if capturedSystemAudio {
                    do {
                        try await VideoConverter.mergeAudioTracks(
                            asset: AVURLAsset(url: self.temporaryOutputURL),
                            outputURL: self.outputURL,
                            fileType: assetwriter.outputFileType,
                            audioOutputSettings: audioOutputSettings
                        )
                    } catch VideoConverter.ConversionError.noAudioTracks {
                        // Keep the video even when no audio sample arrived
                        try FileManager.default.moveItem(at: self.temporaryOutputURL, to: self.outputURL)
                    }
                } else {
                    // The mic track is already AAC, so the first-pass file is final as is
                    try FileManager.default.moveItem(at: self.temporaryOutputURL, to: self.outputURL)
                }
                self.state = .idle
            } catch {
                self.failRecording(error)
            }
        }
    }

    // Synchronous on purpose: this runs for every rendered frame and awaits nothing,
    // so wrapping it in a Task would only add allocations and ordering delays
    public func renderFrame(_ frame: CIImage) {
        guard case .recording = state,
              let assetWriterAdaptor = assetVideoWriterAdaptor else { return }

        // The input is real-time, so drop the frame when the writer can't keep up
        guard assetWriterAdaptor.assetWriterInput.isReadyForMoreMediaData,
              let pixelBufferPool = assetWriterAdaptor.pixelBufferPool else { return }

        var pixelBuffer: CVPixelBuffer?
        let pixelBufferStatus = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        guard pixelBufferStatus == kCVReturnSuccess, let pixelBuffer else {
            failRecording(RecordingError.cannotCreatePixelBuffer(pixelBufferStatus))
            return
        }

        context.render(frame, to: pixelBuffer)

        if frameCount == 0 {
            startDate = Date()
            baseHostTime = mach_absolute_time()

            // Start the session just before appending to avoid latency,
            // as the video's expectsMediaDataInRealTime is true
            assetwriter?.startSession(atSourceTime: CMTime.zero)
        }

        guard assetWriterAdaptor.append(pixelBuffer, withPresentationTime: currentPresentationTime) else {
            // Distinguish a failed writer from transient backpressure; only the former ends the recording
            if let assetwriter, assetwriter.status != .writing {
                failRecording(assetwriter.error ?? RecordingError.appendFailed(.video))
            }
            return
        }
        frameCount += 1
    }

    public func renderAudioFrame(_ pcmBuffer: AVAudioPCMBuffer, time: AVAudioTime, latency: TimeInterval, device: AudioDevice?) async {
        guard case .recording = state, frameCount > 0 else { return }

        if sampleCount <= 0 {
            // Time from start of recording to capture.
            var timeInterval = time.timeIntervalSince(hostTime: baseHostTime)
            if let device {
                // https://lists.apple.com/archives/coreaudio-api/2010/Jan/msg00046.html
                // https://developer.apple.com/forums/thread/131057
                // https://stackoverflow.com/questions/65600996/avaudioengine-reconcile-sync-input-output-timestamps-on-macos-ios
                let syncOffset = -TimeInterval(UserDefaults.standard.value(for: .recordMicSyncOffset)) / 1000
                timeInterval -= latency + device.latencyTimeInterval() + syncOffset
            }
            if timeInterval <= 0 {
                // Discard the audio buffer if it arrives faster than the video buffer
                return
            }
            sampleCount = CMTimeValue(expectedFormat.sampleRate * timeInterval)
        }

        let converter: AudioConverter
        if let currentConverter = self.converter {
            converter = currentConverter
        } else if let newConverter = AudioConverter(from: pcmBuffer.format, to: expectedFormat) {
            converter = newConverter
            self.converter = converter
        } else {
            return
        }

        guard let convertedBuffer = await converter.convert(pcmBuffer),
              let buffer = createSampleBuffer(pcmBuffer: convertedBuffer, sampleCount: &sampleCount) else {
            return
        }
        // createSampleBuffer has already advanced sampleCount, so a dropped
        // buffer leaves a silent gap instead of desyncing the rest of the audio
        guard let assetAudioWriterInput, assetAudioWriterInput.isReadyForMoreMediaData else { return }
        guard assetAudioWriterInput.append(buffer) else {
            if let assetwriter, assetwriter.status != .writing {
                failRecording(assetwriter.error ?? RecordingError.appendFailed(.audio))
            }
            return
        }
    }

    func renderPCAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard case .recording = state, frameCount > 0,
                let formatDescription = sampleBuffer.formatDescription,
              let sampleRate = (formatDescription.audioStreamBasicDescription?.mSampleRate).flatMap(TimeInterval.init),
              var sampleTimingInfo = (try? sampleBuffer.sampleTimingInfos())?.first
        else { return }

        if pcSampleCount == 0 {
            let baseMediaTime = AVAudioTime.seconds(forHostTime: baseHostTime) // = CACurrentMediaTime
            let recordingDelay = sampleBuffer.presentationTimeStamp.seconds - baseMediaTime
            if recordingDelay <= 0 {
                return
            }
            pcSampleCount = CMTimeValue(sampleRate * recordingDelay)
        }

        let newTimeStamp = CMTime(value: pcSampleCount, timescale: CMTimeScale(sampleRate))

        // Optimize by assuming an implementation where entryCount is always 1
        let entryCount = 1 // CMItemCount((try? sampleBuffer.sampleTimingInfos())?.count ?? 0)
//        var infoPointer = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: entryCount)
//        defer {
//            infoPointer.deallocate()
//        }
//        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: entryCount, arrayToFill: infoPointer, entriesNeededOut: &entryCount)

//        for i in 0..<entryCount {
//            infoPointer[i].decodeTimeStamp = .invalid
//            infoPointer[i].presentationTimeStamp = newTimeStamp
//        }
        sampleTimingInfo.decodeTimeStamp = .invalid
        sampleTimingInfo.presentationTimeStamp = newTimeStamp

        var newSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: entryCount, sampleTimingArray: &sampleTimingInfo, sampleBufferOut: &newSampleBuffer)

        // Advance the sample count even for dropped buffers so later audio stays in sync
        defer {
            pcSampleCount += CMTimeValue(sampleBuffer.duration.seconds * sampleRate)
        }

        guard let assetPCAudioWriterInput, assetPCAudioWriterInput.isReadyForMoreMediaData else { return }
        guard assetPCAudioWriterInput.append(newSampleBuffer ?? sampleBuffer) else {
            if let assetwriter, assetwriter.status != .writing {
                failRecording(assetwriter.error ?? RecordingError.appendFailed(.audio))
            }
            return
        }
    }

    var currentPresentationTime: CMTime {
        CMTimeMakeWithSeconds(Date().timeIntervalSince(startDate), preferredTimescale: Int32(NSEC_PER_SEC))
    }

    private func createSampleBuffer(pcmBuffer: AVAudioPCMBuffer, sampleCount: inout CMTimeValue) -> CMSampleBuffer? {
        defer {
            sampleCount += CMTimeValue(pcmBuffer.frameLength)
        }
        return try? CMSampleBuffer.create(pcmBuffer: pcmBuffer, sampleCount: sampleCount)
    }

    private func releaseWriterInputs() {
        assetVideoWriterAdaptor = nil
        assetAudioWriterInput = nil
        assetPCAudioWriterInput = nil
        converter = nil
    }

    private func failRecording(_ error: Error) {
        // cancelWriting raises an exception unless the writer is actually writing
        if let assetwriter, assetwriter.status == .writing {
            assetwriter.cancelWriting()
        }
        assetwriter = nil
        releaseWriterInputs()
        if let systemAudioRecorder {
            Task { await systemAudioRecorder.stopCapture() }
        }
        systemAudioRecorder = nil
        AvatarAudioManager.shared.stop(usage: .record)
        // The writer may have already created the file (setup failures included)
        if let temporaryOutputURL {
            try? FileManager.default.removeItem(at: temporaryOutputURL)
        }
        state = .idle
        Logger.error(error)
    }
}

extension AVAudioPCMBuffer: @unchecked @retroactive Sendable {}
