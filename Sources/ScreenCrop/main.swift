import AppKit
import Carbon.HIToolbox

private var hotKeyAction: (() -> Void)?

private func registerHotKey(_ action: @escaping () -> Void) {
    hotKeyAction = action
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        hotKeyAction?()
        return noErr
    }, 1, &spec, nil, nil)
    var ref: EventHotKeyRef?
    RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(cmdKey | optionKey | controlKey),
                        EventHotKeyID(signature: 0x5343_5250, id: 1), GetApplicationEventTarget(), 0, &ref)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let crop = Crop()
    private var statusItem: NSStatusItem?
    /// What the user asked for. The crop is actually on only while no external display is connected.
    private var wanted = true
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◧"
        statusItem = item
        crop.onChange = { [weak self] in self?.rebuildMenu() }
        crop.onError = { [weak self] error in self?.report(error) }
        rebuildMenu()

        registerHotKey { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.crop.screensChanged()
                self?.apply()
            }
        }

        // `--for N` quits after N seconds, as a safe trial run.
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--for"), index + 1 < args.count, let seconds = Double(args[index + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
        }
        apply()
    }

    func applicationWillTerminate(_ notification: Notification) {
        crop.disable()
    }

    @objc private func toggle() {
        wanted.toggle()
        lastError = nil
        apply()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var externalConnected: Bool {
        onlineDisplays().contains { CGDisplayIsBuiltin($0) == 0 && $0 != crop.virtualID }
    }

    private func apply() {
        if wanted && !externalConnected {
            guard !crop.isOn else { return }
            Task {
                do {
                    try await crop.enable()
                } catch {
                    report(error)
                }
            }
        } else {
            crop.disable()
        }
        rebuildMenu()
    }

    private func report(_ error: Error) {
        NSLog("ScreenCrop: \(error.localizedDescription)")
        lastError = error.localizedDescription
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let state: String
        if crop.isOn {
            state = "On"
        } else if wanted && externalConnected {
            state = "Paused: external display connected"
        } else {
            state = "Off"
        }
        menu.addItem(withTitle: "ScreenCrop: \(state)", action: nil, keyEquivalent: "")
        if let lastError {
            menu.addItem(withTitle: lastError, action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let toggleItem = NSMenuItem(title: wanted ? "Turn Off (⌃⌥⌘C)" : "Turn On (⌃⌥⌘C)",
                                    action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
