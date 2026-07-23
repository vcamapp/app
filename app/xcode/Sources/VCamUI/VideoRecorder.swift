import Foundation
import CoreImage
import AVFoundation
import AppKit
import VCamEntity
import VCamMedia
import VCamTracking
import VCamLogger

public enum RecordingState {
    case idle
    case preparing
    case recording
    case finishing
}

private enum RecordingError: LocalizedError {
    case appendFailed(AVMediaType)

    var errorDescription: String? {
        switch self {
        case let .appendFailed(mediaType): "Failed to append \(mediaType.rawValue) media."
        }
    }
}

@MainActor
@Observable
public final class VideoRecorder { // TODO: Migrate new API for macOS 26+
    public static let shared = VideoRecorder()

    public private(set) var state: RecordingState = .idle
    public var isRecording: Bool {
        if case .recording = state { return true }
        return false
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
    @ObservationIgnored private var pixelBuffer: CVPixelBuffer?
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
        let assetVideoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetVideoWriterInput, sourcePixelBufferAttributes: nil)

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

        self.assetwriter = assetwriter
        self.assetVideoWriterAdaptor = assetVideoWriterAdaptor
        self.assetAudioWriterInput = assetAudioWriterInput
        self.assetPCAudioWriterInput = assetPCAudioWriterInput

        assetVideoWriterInput.expectsMediaDataInRealTime = true
        assetAudioWriterInput.expectsMediaDataInRealTime = false
        assetPCAudioWriterInput?.expectsMediaDataInRealTime = false

        assetwriter.add(assetVideoWriterInput)
        assetwriter.add(assetAudioWriterInput)
        if let assetPCAudioWriterInput {
            assetwriter.add(assetPCAudioWriterInput)
        }

        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            screenResolution.size.width,
            screenResolution.size.height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        assetwriter.startWriting()

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
            Task {
                let debugImage = NSImage(color: .red, size: CGSize(width: 1920, height: 1080)).ciImage!
                await Self.shared.renderFrame(debugImage)
            }
        }
#endif

        Task { @MainActor in
            AvatarAudioManager.shared.start(usage: .record)
        }
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
        let videoOutputSettings = assetVideoWriterAdaptor?.assetWriterInput.outputSettings as? [String: any Sendable] ?? [:]
        let audioOutputSettings = assetAudioWriterInput?.outputSettings as? [String: any Sendable] ?? [:]

        assetVideoWriterAdaptor = nil
        assetAudioWriterInput = nil
        converter = nil
        Task { @MainActor in
            AvatarAudioManager.shared.stop(usage: .record)
        }

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
            self.pixelBuffer = nil
            self.assetwriter = nil

            do {
                try await VideoConverter.mergeAudioTracks(
                    asset: AVURLAsset(url: self.temporaryOutputURL),
                    outputURL: self.outputURL,
                    fileType: assetwriter.outputFileType,
                    videoOutputSettings: videoOutputSettings,
                    audioOutputSettings: audioOutputSettings
                )
                self.state = .idle
            } catch {
                self.failRecording(error)
            }
        }
    }

    public func renderFrame(_ frame: CIImage) async {
        guard case .recording = state,
              let assetWriterAdaptor = assetVideoWriterAdaptor,
              let pixelBuffer else { return }

        context.render(frame, to: pixelBuffer)

        if frameCount == 0 {
            startDate = Date()
            baseHostTime = mach_absolute_time()

            // Start the session just before appending to avoid latency, 
            // as the video's expectsMediaDataInRealTime is true
            assetwriter?.startSession(atSourceTime: CMTime.zero)
        }

        guard assetWriterAdaptor.append(pixelBuffer, withPresentationTime: currentPresentationTime) else {
            failRecording(assetwriter?.error ?? RecordingError.appendFailed(.video))
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
        guard assetAudioWriterInput?.append(buffer) == true else {
            failRecording(assetwriter?.error ?? RecordingError.appendFailed(.audio))
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

        guard assetPCAudioWriterInput?.append(newSampleBuffer ?? sampleBuffer) == true else {
            failRecording(assetwriter?.error ?? RecordingError.appendFailed(.audio))
            return
        }

        pcSampleCount += CMTimeValue(sampleBuffer.duration.seconds * sampleRate)
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

    private func failRecording(_ error: Error) {
        assetwriter?.cancelWriting()
        assetwriter = nil
        assetVideoWriterAdaptor = nil
        assetAudioWriterInput = nil
        assetPCAudioWriterInput = nil
        pixelBuffer = nil
        converter = nil
        if let systemAudioRecorder {
            Task { await systemAudioRecorder.stopCapture() }
        }
        systemAudioRecorder = nil
        AvatarAudioManager.shared.stop(usage: .record)
        state = .idle
        Logger.error(error)
    }
}

extension AVAudioPCMBuffer: @unchecked @retroactive Sendable {}
