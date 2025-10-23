//
//  VideoConverter.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/27.
//

import Foundation
import AVFoundation

@globalActor private actor VideoConverterActor {
    static let shared = VideoConverterActor()
}

public enum VideoConverter {
    /// Merge audio tracks into a single audio track
    /// - Parameters:
    ///   - asset: A source asset which must have a video asset and some audio tracks.
    ///   - outputURL: Destination of the output.
    ///   - fileType: The file format of the output.
    ///   - videoOutputSettings: The settings to use for encoding the media you append to the output. Create an output settings dictionary manually, or use AVOutputSettingsAssistant to create preset-based settings.
    ///   - audioOutputSettings: The settings to use for encoding the media you append to the output. Create an output settings dictionary manually, or use AVOutputSettingsAssistant to create preset-based settings.
    @VideoConverterActor
    public static func mergeAudioTracks(
        asset: AVAsset,
        outputURL: URL,
        fileType: AVFileType,
        videoOutputSettings: [String : Any],
        audioOutputSettings: [String : Any]
    ) async throws {
        let reader = try AVAssetReader(asset: asset)

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: try await asset.loadTracks(withMediaType: .audio), audioSettings: nil)
        reader.add(audioOutput)

        let videoOutput = AVAssetReaderTrackOutput(track: try await asset.loadTracks(withMediaType: .video)[0], outputSettings: nil)
        reader.add(videoOutput)

        reader.startReading()

        let assetwriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        let formatHint = try CMFormatDescription(
            videoCodecType: .h264, // required
            width: videoOutputSettings[AVVideoWidthKey] as! Int, // required
            height: videoOutputSettings[AVVideoHeightKey] as! Int  // required
        )

        await withCheckedContinuation { continuation in
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatHint)
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)

            videoInput.expectsMediaDataInRealTime = false
            audioInput.expectsMediaDataInRealTime = false

            assetwriter.shouldOptimizeForNetworkUse = true
            assetwriter.add(videoInput)
            assetwriter.add(audioInput)

            assetwriter.startWriting()
            assetwriter.startSession(atSourceTime: .zero)

            let group = DispatchGroup()
            group.enter()
            group.enter()

            let videoQueue = DispatchQueue(label: "vcam.mergeAudioTracks.videoQueue")
            let audioQueue = DispatchQueue(label: "vcam.mergeAudioTracks.audioQueue")

            videoInput.requestMediaDataWhenReadySending(on: videoQueue) {
                while videoInput.isReadyForMoreMediaData {
                    guard let buffer = videoOutput.copyNextSampleBuffer() else {
                        videoInput.markAsFinished()
                        group.leave()
                        break
                    }
                    videoInput.append(buffer)
                }
            }

            audioInput.requestMediaDataWhenReadySending(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    guard let buffer = audioOutput.copyNextSampleBuffer() else {
                        audioInput.markAsFinished()
                        group.leave()
                        break
                    }
                    audioInput.append(buffer)
                }
            }

            group.notify(queue: .main) {
                continuation.resume()
            }
        }

        await assetwriter.finishWriting()
    }
}

extension AVAssetWriterInput {
    func requestMediaDataWhenReadySending(on queue: dispatch_queue_t, using block: sending @escaping () -> Void) {
        requestMediaDataWhenReady(on: queue, using: block)
    }
}
