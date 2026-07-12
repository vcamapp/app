import Foundation
import AVFoundation
import Synchronization

public enum VideoConverter { // TODO: Migrate to new API for macOS 26+
    private final class ConversionState: @unchecked Sendable {
        private let errorStorage = Mutex<Error?>(nil)
        private let finishedInputs = Mutex<Set<String>>([])
        private let completionStorage = Mutex(false)

        var error: Error? {
            errorStorage.withLock { $0 }
        }

        func set(error: Error) {
            errorStorage.withLock { storedError in
                storedError = storedError ?? error
            }
        }

        func finishInput(_ name: String) -> Bool {
            finishedInputs.withLock { inputs in
                inputs.insert(name).inserted
            }
        }

        func complete() -> Bool {
            completionStorage.withLock { completed in
                guard !completed else { return false }
                completed = true
                return true
            }
        }
    }

    private final class ContinuationBox: @unchecked Sendable {
        private let storage = Mutex<CheckedContinuation<Void, Error>?>(nil)

        func store(_ continuation: CheckedContinuation<Void, Error>) {
            storage.withLock { $0 = continuation }
        }
        
        func take() -> CheckedContinuation<Void, Error>? {
            storage.withLock { value in
                defer { value = nil }
                return value
            }
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
        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
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
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw ConversionError.failedToAddWriterInput(.video)
        }
        writer.add(videoInput)
        writer.add(audioInput)
        videoInput.expectsMediaDataInRealTime = false
        audioInput.expectsMediaDataInRealTime = false
        writer.shouldOptimizeForNetworkUse = true

        guard reader.startReading() else { throw ConversionError.failedToStartReading(reader.error) }
        guard writer.startWriting() else { throw ConversionError.failedToStartWriting(writer.error) }
        writer.startSession(atSourceTime: .zero)

        let cancellationBox = ContinuationBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let group = DispatchGroup()
                let state = ConversionState()
                cancellationBox.store(continuation)
                group.enter()
                group.enter()

                let videoQueue = DispatchQueue(label: "vcam.mergeAudioTracks.videoQueue")
                let audioQueue = DispatchQueue(label: "vcam.mergeAudioTracks.audioQueue")

                func fail(_ error: Error) {
                    state.set(error: error)
                    reader.cancelReading()
                    writer.cancelWriting()
                    videoInput.markAsFinished()
                    audioInput.markAsFinished()
                    if state.complete() { cancellationBox.take()?.resume(throwing: error) }
                }

                videoInput.requestMediaDataWhenReady(on: videoQueue) {
                    while videoInput.isReadyForMoreMediaData {
                        guard let buffer = videoOutput.copyNextSampleBuffer() else {
                            videoInput.markAsFinished()
                            if state.finishInput("video") { group.leave() }
                            return
                        }
                        guard videoInput.append(buffer) else {
                            fail(ConversionError.appendFailed(.video, writer.error))
                            return
                        }
                    }
                }
                audioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while audioInput.isReadyForMoreMediaData {
                        guard let buffer = audioOutput.copyNextSampleBuffer() else {
                            audioInput.markAsFinished()
                            if state.finishInput("audio") { group.leave() }
                            return
                        }
                        guard audioInput.append(buffer) else {
                            fail(ConversionError.appendFailed(.audio, writer.error))
                            return
                        }
                    }
                }

                group.notify(queue: .global()) {
                    guard state.complete() else { return }
                    if let error = state.error {
                        cancellationBox.take()?.resume(throwing: error)
                        return
                    }
                    guard reader.status == .completed else {
                        cancellationBox.take()?.resume(throwing: ConversionError.readerFailed(reader.error))
                        return
                    }
                    guard writer.status == .writing || writer.status == .completed else {
                        cancellationBox.take()?.resume(throwing: ConversionError.writerFailed(writer.error))
                        return
                    }
                    writer.finishWriting {
                        if writer.status == .completed {
                            cancellationBox.take()?.resume()
                        } else {
                            cancellationBox.take()?.resume(throwing: ConversionError.writerFailed(writer.error))
                        }
                    }
                }
            }
        } onCancel: {
            reader.cancelReading()
            writer.cancelWriting()
            cancellationBox.take()?.resume(throwing: CancellationError())
        }

        succeeded = true
    }
}
