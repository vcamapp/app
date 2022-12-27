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
    ///   - asset: A source file
    ///   - outputURL: Destination of the output
    ///   - videoOutputSettings: The settings to use for encoding the media you append to the output. Create an output settings dictionary manually, or use AVOutputSettingsAssistant to create preset-based settings.
    ///   - audioOutputSettings: The settings to use for encoding the media you append to the output. Create an output settings dictionary manually, or use AVOutputSettingsAssistant to create preset-based settings.
    @VideoConverterActor
    public static func mergeAudioTracks(
        asset: AVAsset,
        outputURL: URL,
        videoOutputSettings: [String : Any],
        audioOutputSettings: [String : Any]
    ) async throws {
        let reader = try AVAssetReader(asset: asset)

        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: try await asset.loadTracks(withMediaType: .audio), audioSettings: nil)
        reader.add(audioOutput)

        let videoOutput = AVAssetReaderTrackOutput(track: try await asset.loadTracks(withMediaType: .video)[0], outputSettings: nil)
        reader.add(videoOutput)

        reader.startReading()

        let assetwriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: try .init(
            videoCodecType: .h264, // required
            width: videoOutputSettings[AVVideoWidthKey] as! Int, // required
            height: videoOutputSettings[AVVideoHeightKey] as! Int  // required
        ))
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)

        videoInput.expectsMediaDataInRealTime = false
        audioInput.expectsMediaDataInRealTime = false

        assetwriter.shouldOptimizeForNetworkUse = true
        assetwriter.add(videoInput)
        assetwriter.add(audioInput)

        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: .zero)

        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            group.enter()
            group.enter()

            videoInput.requestMediaDataWhenReady(on: .global()) {
                while videoInput.isReadyForMoreMediaData {
                    guard let buffer = videoOutput.copyNextSampleBuffer() else {
                        videoInput.markAsFinished()
                        group.leave()
                        break
                    }
                    videoInput.append(buffer)
                }
            }

            audioInput.requestMediaDataWhenReady(on: .global()) {
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
