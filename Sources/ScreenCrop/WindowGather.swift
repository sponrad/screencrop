import AppKit
import ApplicationServices

/// Moves other apps' windows between displays through the Accessibility API.
enum WindowGather {
    /// Asks for Accessibility permission the first time; returns false until it is granted.
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Moves every window whose center lies in `source` into `target`, keeping its offset and shrinking it to fit.
    /// Both rectangles are in global display coordinates (origin at the top-left of the main display).
    static func move(from source: CGRect, to target: CGRect) {
        guard isTrusted(prompt: true) else {
            NSLog("ScreenCrop: gather skipped, no Accessibility permission")
            return
        }
        var moved = 0
        defer { NSLog("ScreenCrop: gathered \(moved) windows from \(source) to \(target)") }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement]
            else { continue }
            for window in windows {
                guard !isFullScreen(window), let frame = frame(of: window),
                      source.contains(CGPoint(x: frame.midX, y: frame.midY))
                else { continue }
                let size = CGSize(width: min(frame.width, target.width), height: min(frame.height, target.height))
                let origin = CGPoint(
                    x: min(max(target.minX + frame.minX - source.minX, target.minX), target.maxX - size.width),
                    y: min(max(target.minY + frame.minY - source.minY, target.minY), target.maxY - size.height)
                )
                set(window, size: size)
                set(window, position: origin)
                moved += 1
            }
        }
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size
        else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }

    private static func set(_ window: AXUIElement, size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
    }

    private static func set(_ window: AXUIElement, position: CGPoint) {
        var value = position
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
    }
}
