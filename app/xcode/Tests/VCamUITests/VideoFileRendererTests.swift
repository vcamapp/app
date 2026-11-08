import AVFoundation
import Foundation
import Testing
@testable import VCamUI

@MainActor
@Suite(.serialized)
struct VideoFileRendererTests {
    private static let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appending(path: "VideoFileRendererTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static func writeVideo(name: String, width: Int = 64, height: Int = 32, seconds: Double = 0.3, transform: CGAffineTransform = .identity) async throws -> URL {
        let url = directory.appending(path: name)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let frameRate = 30
        for frame in 0..<Int(seconds * Double(frameRate)) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(1))
            }
            let pool = try #require(adaptor.pixelBufferPool)
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            memset(CVPixelBufferGetBaseAddress(pixels), Int32(frame * 8 % 255), CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test
    func theSizeIsTheOneTheFramesAreStoredAt() async throws {
        let url = try await Self.writeVideo(name: "plain.mp4")

        #expect(try await VideoFileRenderer.size(of: url) == CGSize(width: 64, height: 32))
    }

    @Test
    func theSizeFollowsTheRotationTheFileAsksFor() async throws {
        let url = try await Self.writeVideo(name: "rotated.mp4", transform: CGAffineTransform(rotationAngle: .pi / 2))

        #expect(try await VideoFileRenderer.size(of: url) == CGSize(width: 32, height: 64))
    }

    @Test
    func aFileThatIsNotAVideoIsRefused() async throws {
        let url = Self.directory.appending(path: "garbage.mp4")
        try Data("not a video".utf8).write(to: url)

        await #expect(throws: VideoFileRenderer.LoadError.self) {
            try await VideoFileRenderer.size(of: url)
        }
    }

    @Test
    func framesReachTheTexture() async throws {
        let url = try await Self.writeVideo(name: "frames.mp4", seconds: 1)
        let renderer = VideoFileRenderer(url: url, size: .init(width: 64, height: 32), isLooping: true, isMuted: true)
        defer { renderer.stopRendering() }
        var frames = 0
        var extent = CGRect.zero

        renderer.setRenderTexture { image in
            frames += 1
            extent = image.extent
        }

        try await waitUntil { frames > 2 }
        #expect(extent.size == CGSize(width: 64, height: 32))
    }

    @Test
    func aVideoThatDoesNotLoopStopsAtItsEndAndStartsOverWhenPlayed() async throws {
        let url = try await Self.writeVideo(name: "once.mp4")
        let renderer = VideoFileRenderer(url: url, size: .init(width: 64, height: 32), isLooping: false, isMuted: true)
        defer { renderer.stopRendering() }

        try await waitUntil { !renderer.isPlaying }

        renderer.setPlaying(true)
        #expect(renderer.isPlaying)
        try await waitUntil { renderer.time < 0.25 || !renderer.isPlaying }
    }

    @Test
    func aLoopingVideoKeepsPlayingPastItsEnd() async throws {
        let url = try await Self.writeVideo(name: "loop.mp4", seconds: 0.2)
        let renderer = VideoFileRenderer(url: url, size: .init(width: 64, height: 32), isLooping: true, isMuted: true)
        defer { renderer.stopRendering() }

        try await Task.sleep(for: .milliseconds(700))

        #expect(renderer.isPlaying)
    }

    @Test
    func hidingPausesAndShowingContinues() async throws {
        let url = try await Self.writeVideo(name: "hidden.mp4", seconds: 3)
        let renderer = VideoFileRenderer(url: url, size: .init(width: 64, height: 32), isLooping: true, isMuted: true)
        defer { renderer.stopRendering() }
        try await waitUntil { renderer.time > 0.05 }

        renderer.isObjectHidden = true
        try await Task.sleep(for: .milliseconds(100))
        let hiddenTime = renderer.time
        try await Task.sleep(for: .milliseconds(200))

        #expect(renderer.time == hiddenTime)
        #expect(renderer.isPlaying)

        renderer.isObjectHidden = false
        try await waitUntil { renderer.time > hiddenTime }
    }

    @Test
    func theLengthComesFromTheFile() async throws {
        let url = try await Self.writeVideo(name: "length.mp4", seconds: 1)
        let renderer = VideoFileRenderer(url: url, size: .init(width: 64, height: 32), isLooping: false, isMuted: true)
        defer { renderer.stopRendering() }

        #expect(abs(await renderer.duration() - 1) < 0.1)
    }
}
