import Foundation
import AVFoundation
import Synchronization

public enum VideoConverter { // TODO: Migrate to new API for macOS 26+
    /// Guarantees the continuation is resumed exactly once, whichever of the
    /// drain, failure and cancellation paths gets there first.
    private final class ConversionState: @unchecked Sendable {
        private struct Storage {
            var pendingInputs: Set<AVMediaType> = [.video, .audio]
            var continuation: CheckedContinuation<Void, Error>?
            var finishedResult: Result<Void, Error>?
        }

        private let storage = Mutex(Storage())

        /// Cancellation can win the race against the continuation being stored,
        /// so one handed over after `finish()` resumes right away.
        func store(_ continuation: CheckedContinuation<Void, Error>) {
            let result = storage.withLock { state -> Result<Void, Error>? in
                guard let result = state.finishedResult else {
                    state.continuation = continuation
                    return nil
                }
                return result
            }
            if let result { continuation.resume(with: result) }
        }

        /// Returns true only for the input that drains last.
        func finishInput(_ mediaType: AVMediaType) -> Bool {
            storage.withLock { state in
                guard state.pendingInputs.remove(mediaType) != nil, state.finishedResult == nil else { return false }
                return state.pendingInputs.isEmpty
            }
        }

        func finish(with result: Result<Void, Error>) {
            let continuation = storage.withLock { state -> CheckedContinuation<Void, Error>? in
                guard state.finishedResult == nil else { return nil }
                state.finishedResult = result
                defer { state.continuation = nil }
                return state.continuation
            }
            continuation?.resume(with: result)
        }
    }

    public enum ConversionError: LocalizedError {
        case noVideoTrack
        case noAudioTracks
        case invalidVideoOutputSettings
        case failedToAddReaderOutput
        case failedToAddWriterInput(AVMediaType)
        case readerFailed(Error?)
        case writerFailed(Error?)
        case appendFailed(AVMediaType, Error?)
        case failedToStartReading(Error?)
        case failedToStartWriting(Error?)

        public var errorDescription: String? {
            switch self {
            case .noVideoTrack: "The asset does not contain a video track."
            case .noAudioTracks: "The asset does not contain an audio track."
            case .invalidVideoOutputSettings: "The video output settings do not contain valid dimensions."
            case .failedToAddReaderOutput: "Failed to add an output to the asset reader."
            case let .failedToAddWriterInput(mediaType): "Failed to add the \(mediaType.rawValue) input to the asset writer."
            case let .readerFailed(error): "The asset reader failed: \(error?.localizedDescription ?? "unknown error")"
            case let .writerFailed(error): "The asset writer failed: \(error?.localizedDescription ?? "unknown error")"
            case let .appendFailed(mediaType, error): "Failed to append the \(mediaType.rawValue) sample: \(error?.localizedDescription ?? "unknown error")"
            case let .failedToStartReading(error): "Failed to start reading: \(error?.localizedDescription ?? "unknown error")"
            case let .failedToStartWriting(error): "Failed to start writing: \(error?.localizedDescription ?? "unknown error")"
            }
        }
    }

    /// Merge audio tracks into a single audio track.
    @concurrent
    public static func mergeAudioTracks(
        asset: AVAsset,
        outputURL: URL,
        fileType: AVFileType,
        videoOutputSettings: sending [String: Any],
        audioOutputSettings: sending [String: Any]
    ) async throws {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw ConversionError.noVideoTrack }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw ConversionError.noAudioTracks }

        guard let width = videoOutputSettings[AVVideoWidthKey] as? Int,
              let height = videoOutputSettings[AVVideoHeightKey] as? Int else {
            throw ConversionError.invalidVideoOutputSettings
        }

        nonisolated(unsafe) let reader = try AVAssetReader(asset: asset)
        nonisolated(unsafe) let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        nonisolated(unsafe) let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        guard reader.canAdd(audioOutput), reader.canAdd(videoOutput) else {
            throw ConversionError.failedToAddReaderOutput
        }
        reader.add(audioOutput)
        reader.add(videoOutput)

        nonisolated(unsafe) let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        var succeeded = false
        defer {
            if !succeeded {
                reader.cancelReading()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: outputURL)
            }
        }

        let formatHint = try CMFormatDescription(videoCodecType: .h264, width: width, height: height)
        nonisolated(unsafe) let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
        nonisolated(unsafe) let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        guard writer.canAdd(videoInput) else { throw ConversionError.failedToAddWriterInput(.video) }
        guard writer.canAdd(audioInput) else { throw ConversionError.failedToAddWriterInput(.audio) }
        writer.add(videoInput)
        writer.add(audioInput)
        videoInput.expectsMediaDataInRealTime = false
        audioInput.expectsMediaDataInRealTime = false
        writer.shouldOptimizeForNetworkUse = true

        guard reader.startReading() else { throw ConversionError.failedToStartReading(reader.error) }
        guard writer.startWriting() else { throw ConversionError.failedToStartWriting(writer.error) }
        writer.startSession(atSourceTime: .zero)

        let state = ConversionState()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                state.store(continuation)

                @Sendable func fail(_ error: Error) {
                    reader.cancelReading()
                    writer.cancelWriting()
                    videoInput.markAsFinished()
                    audioInput.markAsFinished()
                    state.finish(with: .failure(error))
                }

                @Sendable func finishWriting() {
                    guard reader.status == .completed else {
                        return fail(ConversionError.readerFailed(reader.error))
                    }
                    guard writer.status == .writing || writer.status == .completed else {
                        return fail(ConversionError.writerFailed(writer.error))
                    }
                    writer.finishWriting {
                        if writer.status == .completed {
                            state.finish(with: .success(()))
                        } else {
                            state.finish(with: .failure(ConversionError.writerFailed(writer.error)))
                        }
                    }
                }

                @Sendable func drain(
                    _ input: sending AVAssetWriterInput,
                    from output: sending AVAssetReaderOutput,
                    mediaType: AVMediaType
                ) {
                    nonisolated(unsafe) let input = input
                    nonisolated(unsafe) let output = output
                    input.requestMediaDataWhenReady(on: DispatchQueue(label: "vcam.mergeAudioTracks.\(mediaType.rawValue)")) {
                        while input.isReadyForMoreMediaData {
                            guard let buffer = output.copyNextSampleBuffer() else {
                                input.markAsFinished()
                                if state.finishInput(mediaType) {
                                    DispatchQueue.global().async(execute: finishWriting)
                                }
                                return
                            }
                            guard input.append(buffer) else {
                                return fail(ConversionError.appendFailed(mediaType, writer.error))
                            }
                        }
                    }
                }

                drain(videoInput, from: videoOutput, mediaType: .video)
                drain(audioInput, from: audioOutput, mediaType: .audio)
            }
        } onCancel: {
            reader.cancelReading()
            writer.cancelWriting()
            state.finish(with: .failure(CancellationError()))
        }

        succeeded = true
    }
}
