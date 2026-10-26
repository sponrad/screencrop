import AppKit
import CoreMedia
import CVirtualDisplay
import ScreenCaptureKit

enum CropError: LocalizedError {
    case noBuiltinDisplay
    case noScreenRecordingPermission
    case virtualDisplayFailed
    case virtualDisplayMissing

    var errorDescription: String? {
        switch self {
        case .noBuiltinDisplay: "The built-in display is not online."
        case .noScreenRecordingPermission:
            "ScreenCrop needs Screen Recording permission. Grant it in System Settings > Privacy & Security, then toggle again."
        case .virtualDisplayFailed: "macOS did not create the virtual display."
        case .virtualDisplayMissing: "The virtual display did not appear in ScreenCaptureKit."
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

func onlineDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

func builtinDisplayID() -> CGDirectDisplayID? {
    onlineDisplays().first { CGDisplayIsBuiltin($0) != 0 }
}

/// Usable area of the built-in panel, in points, anchored at the top-left corner.
struct CropSize {
    let width: Int
    let height: Int

    static func fromDefaults() -> CropSize {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: "width")
        let height = defaults.integer(forKey: "height")
        return CropSize(width: width > 0 ? width : 1300, height: height > 0 ? height : 982)
    }
}

/// Capture frame rate. The virtual display itself always refreshes at 60 Hz.
func frameRateFromDefaults() -> Int {
    let fps = UserDefaults.standard.integer(forKey: "fps")
    return fps > 0 ? min(fps, 60) : 60
}

/// Receives frames on a background queue and puts them on the overlay layer.
final class FrameSink: NSObject, SCStreamOutput, SCStreamDelegate {
    weak var layer: CALayer?
    let onStop: (Error) -> Void

    init(onStop: @escaping (Error) -> Void) {
        self.onStop = onStop
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = surface
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onStop(error) }
    }
}

@MainActor
final class Crop {
    private(set) var virtualDisplay: CGVirtualDisplay?
    private var builtinID: CGDirectDisplayID = 0
    private var stream: SCStream?
    private var sink: FrameSink?
    private var window: NSWindow?
    private var frameLayer: CALayer?
    private var fence: Any?
    private var busy = false
    private var size = CropSize.fromDefaults()
    private(set) var frameRate = frameRateFromDefaults()

    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?

    var isOn: Bool { stream != nil }
    var virtualID: CGDirectDisplayID? { virtualDisplay?.displayID }

    func enable() async throws {
        guard !isOn, !busy else { return }
        busy = true
        defer { busy = false }

        size = CropSize.fromDefaults()
        frameRate = frameRateFromDefaults()
        guard let builtin = builtinDisplayID() else { throw CropError.noBuiltinDisplay }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw CropError.noScreenRecordingPermission
        }
        builtinID = builtin

        let display = try makeVirtualDisplay(builtin: builtin)
        virtualDisplay = display
        do {
            let scDisplay = try await waitForDisplay(display.displayID)
            try await startCapture(scDisplay)
        } catch {
            teardown()
            throw error
        }
        makeMain(display.displayID)
        showOverlay()
        startFence()
        onChange?()
    }

    /// Applies a new frame rate to a running capture without rebuilding the virtual display,
    /// so full-screen apps on it stay put.
    func reloadFrameRate() async {
        let next = frameRateFromDefaults()
        guard next != frameRate else { return }
        frameRate = next
        guard let stream, !busy else { return }
        do {
            try await stream.updateConfiguration(streamConfiguration())
        } catch {
            onError?(error)
        }
    }

    func disable() {
        guard virtualDisplay != nil || isOn else { return }
        teardown()
        onChange?()
    }

    /// Screen frames change after any display reconfiguration, so the overlay follows the built-in screen.
    func screensChanged() {
        guard let window, let screen = NSScreen.screens.first(where: { $0.displayID == builtinID }) else { return }
        window.setFrame(screen.frame, display: true)
        layoutFrameLayer(in: screen.frame.size)
    }

    private func teardown() {
        if let fence {
            NSEvent.removeMonitor(fence)
        }
        fence = nil
        window?.orderOut(nil)
        window = nil
        frameLayer = nil
        stream?.stopCapture { _ in }
        stream = nil
        sink = nil
        // Releasing the object removes the display; macOS moves its windows back to the built-in screen.
        virtualDisplay = nil
    }

    private func makeVirtualDisplay(builtin: CGDirectDisplayID) throws -> CGVirtualDisplay {
        let builtinMM = CGDisplayScreenSize(builtin)
        let builtinPoints = CGDisplayBounds(builtin).size
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "ScreenCrop"
        descriptor.maxPixelsWide = UInt32(size.width * 2)
        descriptor.maxPixelsHigh = UInt32(size.height * 2)
        descriptor.sizeInMillimeters = CGSize(
            width: builtinMM.width * CGFloat(size.width) / builtinPoints.width,
            height: builtinMM.height * CGFloat(size.height) / builtinPoints.height
        )
        descriptor.vendorID = 0x5343
        descriptor.productID = 0x5250
        descriptor.serialNum = 1
        descriptor.terminationHandler = { _, _ in }

        let display = CGVirtualDisplay(descriptor: descriptor)
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        // 60 Hz only: games such as Factorio tie their simulation to the refresh rate and run at half speed at 30 Hz.
        settings.modes = [
            CGVirtualDisplayMode(width: UInt(size.width * 2), height: UInt(size.height * 2), refreshRate: 60),
            CGVirtualDisplayMode(width: UInt(size.width), height: UInt(size.height), refreshRate: 60),
        ]
        guard display.displayID != 0, display.apply(settings) else { throw CropError.virtualDisplayFailed }
        return display
    }

    /// The new display shows up a moment after creation; pick its mode once it is online.
    private func waitForDisplay(_ id: CGDirectDisplayID) async throws -> SCDisplay {
        for _ in 0..<40 {
            if selectMode(id) {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                if let display = content.displays.first(where: { $0.displayID == id }) {
                    return display
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw CropError.virtualDisplayMissing
    }

    private func selectMode(_ id: CGDirectDisplayID) -> Bool {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode],
              let mode = modes.first(where: {
                  $0.width == size.width && $0.height == size.height
                      && $0.pixelWidth == size.width * 2
              })
        else { return false }
        if let current = CGDisplayCopyDisplayMode(id), current.width == mode.width,
           current.pixelWidth == mode.pixelWidth {
            return true
        }
        return CGDisplaySetDisplayMode(id, mode, nil) == .success
    }

    private func streamConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = size.width * 2
        config.height = size.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 5
        return config
    }

    private func startCapture(_ display: SCDisplay) async throws {
        let config = streamConfiguration()
        let sink = FrameSink { [weak self] error in
            NSLog("ScreenCrop: stream stopped: \(error)")
            self?.disable()
            self?.onError?(error)
        }
        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                              configuration: config, delegate: sink)
        try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screencrop.frames"))
        try await stream.startCapture()
        self.sink = sink
        self.stream = stream
    }

    /// The main display sits at the origin. The built-in screen touches it only at the bottom-right corner,
    /// so the cursor rarely wanders onto the hidden desktop.
    private func makeMain(_ id: CGDirectDisplayID) {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayOrigin(config, id, 0, 0)
        CGConfigureDisplayOrigin(config, builtinID, Int32(size.width), Int32(size.height))
        CGCompleteDisplayConfiguration(config, .forSession)
    }

    private func showOverlay() {
        let frame = NSScreen.screens.first(where: { $0.displayID == builtinID })?.frame
            ?? CGDisplayBounds(builtinID)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.sharingType = .none

        let root = CALayer()
        root.backgroundColor = NSColor.black.cgColor
        let view = NSView()
        view.layer = root
        view.wantsLayer = true
        window.contentView = view

        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.contentsScale = 2
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        layer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        root.addSublayer(layer)
        frameLayer = layer
        sink?.layer = layer

        window.setFrame(frame, display: false)
        layoutFrameLayer(in: frame.size)
        window.orderFrontRegardless()
        self.window = window
    }

    private func layoutFrameLayer(in screenSize: CGSize) {
        frameLayer?.frame = CGRect(
            x: 0, y: screenSize.height - CGFloat(size.height),
            width: CGFloat(size.width), height: CGFloat(size.height)
        )
    }

    private func startFence() {
        let builtin = builtinID
        guard let virtual = virtualID else { return }
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        fence = NSEvent.addGlobalMonitorForEvents(matching: moves) { event in
            guard let point = event.cgEvent?.location else { return }
            let target = CGDisplayBounds(virtual)
            guard CGDisplayBounds(builtin).contains(point), !target.contains(point) else { return }
            let clamped = CGPoint(
                x: min(max(point.x, target.minX), target.maxX - 1),
                y: min(max(point.y, target.minY), target.maxY - 1)
            )
            CGWarpMouseCursorPosition(clamped)
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }
}
