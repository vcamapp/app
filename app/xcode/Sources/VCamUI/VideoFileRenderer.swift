import AVFoundation
import CoreImage
import VCamEntity

/// Plays a video file into an object's texture. The sound goes to the system's default output.
@MainActor
public final class VideoFileRenderer {
    public enum LoadError: Error {
        case unplayable
    }

    /// Often enough for any frame rate; a poll that finds no new frame costs next to nothing
    private static let pollInterval = Duration.milliseconds(8)

    /// The size frames come out at, after the rotation the file asks for.
    /// AVFoundation goes by the file extension, so `url` must have one.
    public static func size(of url: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform),
              (try? await asset.load(.isPlayable)) == true
        else {
            throw LoadError.unplayable
        }
        let rotated = CGRect(origin: .zero, size: naturalSize).applying(transform).size
        return CGSize(width: abs(rotated.width), height: abs(rotated.height))
    }

    public private(set) var size: CGSize
    public let cropRect: CGRect
    public var filter: ImageFilter? {
        didSet { outputLastFrame() }
    }

    public var isLooping: Bool
    public var isMuted: Bool {
        didSet { player.isMuted = isMuted }
    }
    /// A hidden video pauses, so that nothing unseen keeps sounding
    public var isObjectHidden: Bool {
        didSet { applyPlayback() }
    }

    public private(set) var isPlaying = true
    public var time: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    private let asset: AVURLAsset
    private let player: AVPlayer
    private let item: AVPlayerItem
    private let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
    ])
    private var hasReachedEnd = false
    private var isSystemPaused = false
    private var lastFrame = CIImage.empty()
    private var didFrameOutput: ((CIImage) -> Void)?
    private var pollTask: Task<Void, Never>?
    private var endObserver: (any NSObjectProtocol)?

    public init(url: URL, size: CGSize, cropRect: CGRect = .init(x: 0, y: 0, width: 1, height: 1), isLooping: Bool, isMuted: Bool, isObjectHidden: Bool = false, filter: ImageFilter? = nil) {
        self.size = size
        self.cropRect = cropRect
        self.isLooping = isLooping
        self.isMuted = isMuted
        self.isObjectHidden = isObjectHidden
        self.filter = filter
        asset = AVURLAsset(url: url)
        item = AVPlayerItem(asset: asset)
        item.add(output)
        player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didReachEnd() }
        }
        Task { [weak self] in
            await self?.applyRotation()
        }
        applyPlayback()
    }

    public func duration() async -> Double {
        guard let duration = try? await asset.load(.duration), duration.seconds.isFinite else { return 0 }
        return duration.seconds
    }

    public func setPlaying(_ isPlaying: Bool) {
        if isPlaying, hasReachedEnd {
            seek(to: 0)
        }
        self.isPlaying = isPlaying
        applyPlayback()
    }

    public func seek(to seconds: Double) {
        hasReachedEnd = false
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func didReachEnd() {
        if isLooping {
            seek(to: 0)
            applyPlayback()
        } else {
            hasReachedEnd = true
            isPlaying = false
        }
    }

    private func applyPlayback() {
        if isPlaying, !isObjectHidden, !isSystemPaused {
            player.play()
        } else {
            player.pause()
        }
    }

    /// The video output hands out frames as they are stored, without the rotation a phone records
    private func applyRotation() async {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let transform = try? await track.load(.preferredTransform), !transform.isIdentity,
              let composition = try? await AVVideoComposition.videoComposition(withPropertiesOf: asset)
        else { return }
        item.videoComposition = composition
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.outputNewFrame()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func outputNewFrame() {
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }
        lastFrame = CIImage(cvPixelBuffer: pixelBuffer)
        outputLastFrame()
    }

    private func outputLastFrame() {
        guard !lastFrame.extent.isEmpty else { return }
        didFrameOutput?(filter?.apply(to: lastFrame) ?? lastFrame)
    }
}

extension VideoFileRenderer: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        didFrameOutput = updator
        outputLastFrame()
        startPolling()
    }

    public func snapshot() -> CIImage {
        lastFrame
    }

    public func updateTextureSizeIfNeeded(imageWidth width: CGFloat, imageHeight height: CGFloat) -> Bool {
        guard width != size.width || height != size.height else { return false }
        size = .init(width: width, height: height)
        return true
    }

    public func disableRenderTexture() {
        didFrameOutput = nil
        stopPolling()
    }

    public func pauseRendering() {
        isSystemPaused = true
        applyPlayback()
        stopPolling()
    }

    public func resumeRendering() {
        isSystemPaused = false
        applyPlayback()
        if didFrameOutput != nil {
            startPolling()
        }
    }

    public func stopRendering() {
        disableRenderTexture()
        player.pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }
}
