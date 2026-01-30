import AppKit

@MainActor
@Observable
public final class PasteboardObserver {
    public static let shared = PasteboardObserver()

    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    @ObservationIgnored private var lastChangeCount: Int = 0

    private let pasteboard: NSPasteboard = .general

    public private(set) var imageURL: URL?

    private init() {
        observe()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    public func observe() {
        timer?.invalidate()
        timer = Timer.scheduledTimerOnMain(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.lastChangeCount != self.pasteboard.changeCount {
                self.lastChangeCount = self.pasteboard.changeCount
                try? self.updateState()
            }
        }
    }

    public func dispose() {
        timer?.invalidate()
        timer = nil
    }

    private func updateState() throws {
        let classes = [NSImage.self]
        imageURL = nil
        guard pasteboard.canReadObject(forClasses: classes, options: [:]) else {
            return
        }

        let objectsToPaste = pasteboard.readObjects(forClasses: classes, options: [:]) ?? []

        if let image = objectsToPaste.first as? NSImage {
            let url = URL.temporaryDirectory.appending(path: "vcam_clipboard.png")
            try image.writeAsPNG(to: url)
            imageURL = url
        }
    }
}

extension Timer {
    @MainActor @discardableResult static func scheduledTimerOnMain(withTimeInterval: TimeInterval, repeats: Bool, block: @escaping @MainActor (Timer) -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: withTimeInterval, repeats: repeats) { timer in
            nonisolated(unsafe) let timer: Timer = timer
            MainActor.assumeIsolated {
                block(timer)
            }
        }
    }
}
