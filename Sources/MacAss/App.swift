import AppKit
import SwiftUI
import Combine
import NotchCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
        let editor = super.fieldEditor(createFlag, for: object)
        (editor as? NSTextView)?.allowsUndo = true
        return editor
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            let selectors: [String: Selector] = ["c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)),
                "x": #selector(NSText.cut(_:)), "a": #selector(NSText.selectAll(_:)),
                "z": NSSelectorFromString(event.modifierFlags.contains(.shift) ? "redo:" : "undo:")]
            if let key = event.charactersIgnoringModifiers?.lowercased(), let selector = selectors[key],
               NSApp.sendAction(selector, to: nil, from: self) { return true }
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    let music = Music()
    private var panel: NotchPanel!
    private var root: NotchRootView!
    private var status: NSStatusItem!
    private var verificationBackdrop: NSWindow?
    private let pointer = PointerWatcher()
    private var layout: NotchLayout?
    private var subscriptions = Set<AnyCancellable>()
    private var monitors: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditMenu()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "MacAss")
        let menu = NSMenu()
        for (title, action) in [("Open workspace", #selector(openShelf)), ("Settings", #selector(openSettings)), ("Quit", #selector(quit))] {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: ""); item.target = self
        }
        status.menu = menu
        configureScreen()
        store.$expanded.removeDuplicates().sink { [weak self] open in
            DispatchQueue.main.async { guard let self else { return }; self.updateInteraction(open: self.store.expanded) }
        }.store(in: &subscriptions)
        monitors.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureScreen() }
        })
        monitors.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.expanded = false }
        })
        if let index = CommandLine.arguments.firstIndex(of: "--verify-scene"), CommandLine.arguments.count > index + 1 {
            let scene = CommandLine.arguments[index + 1]
            if let screen = NSScreen.main {
                let backdrop = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                backdrop.contentView = NSHostingView(rootView: LinearGradient(colors: [Color(red: 0.18, green: 0.27, blue: 0.36), Color(red: 0.43, green: 0.52, blue: 0.57)], startPoint: .topLeading, endPoint: .bottomTrailing))
                backdrop.isReleasedWhenClosed = false; backdrop.orderBack(nil); verificationBackdrop = backdrop
            }
            store.installVerificationScene(scene); music.installVerificationScene()
            store.expanded = scene != "compact"; store.pinned = true
        } else if CommandLine.arguments.contains("--verify-editing") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.verifyEditing() }
        } else if CommandLine.arguments.contains("--show-window") { openShelf(); store.pinned = true }
    }
    @objc func configureScreen() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let left = screen.auxiliaryTopLeftArea, right = screen.auxiliaryTopRightArea
        let width = left != nil && right != nil ? screen.frame.width - left!.width - right!.width : 180
        let center = left.map { screen.frame.minX + $0.width + width / 2 } ?? screen.frame.midX
        let next = NotchLayout(screen: screen.frame, notchWidth: width, notchHeight: max(28, screen.safeAreaInsets.top), centerX: center)
        guard next != layout else { return }
        pointer.stop(); panel?.close(); layout = next
        panel = NotchPanel(contentRect: next.windowFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .statusBar; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        root = NotchRootView(frame: CGRect(origin: .zero, size: next.windowFrame.size))
        root.autoresizingMask = [.width, .height]
        let hosting = NSHostingView(rootView: NotchView(store: store, music: music, layout: next))
        hosting.sizingOptions = []
        hosting.frame = root.bounds; hosting.autoresizingMask = [.width, .height]; root.addSubview(hosting)
        root.onDragEntered = { [weak self] in self?.store.tab = "files"; self?.store.expanded = true }
        root.onDrop = { [weak self] urls in urls.forEach { self?.store.addFile($0) }; return !urls.isEmpty }
        root.onTextDrop = { [weak self] text in self?.store.addText(text); return true }
        panel.contentView = root; panel.setFrame(next.windowFrame, display: false)
        pointer.openRect = next.screenRect(expanded: false)
        pointer.closeRect = next.screenRect(expanded: true).insetBy(dx: -10, dy: -10)
        pointer.warmZone = CGRect(x: screen.frame.minX, y: screen.frame.maxY - 240, width: screen.frame.width, height: 242)
        pointer.openDelay = { 0.10 }; pointer.closeDelay = 0.35
        pointer.isPanelOpen = { [weak self] in self?.store.expanded ?? false }
        pointer.isDragging = { [weak self] in self?.root.isReceivingDrag ?? false }
        pointer.onChange = { [weak self] inside in
            guard let self else { return }
            if !inside && (self.store.pinned || self.store.dialogOpen) { return }
            self.store.expanded = inside
        }
        pointer.onInteractiveChange = { [weak self] interactive in self?.panel.ignoresMouseEvents = !interactive }
        updateInteraction(open: store.expanded)
        panel.orderFrontRegardless(); pointer.start()
    }
    private func updateInteraction(open: Bool) {
        guard let layout else { return }
        root.activeRect = layout.localRect(expanded: open)
        var interactive = layout.screenRect(expanded: open)
        if open {
            interactive.size.height -= layout.notchHeight + 2
        }
        pointer.interactiveRect = interactive
        root.activeRect = interactive.offsetBy(dx: -layout.windowFrame.minX, dy: -layout.windowFrame.minY)
        pointer.setInside(open)
        if !open { panel.resignKey() }
        panel.ignoresMouseEvents = !pointer.interactiveRect.contains(NSEvent.mouseLocation)
    }
    @objc func openShelf() { store.tab = "tasks"; store.expanded = true; panel.makeKeyAndOrderFront(nil) }
    @objc func openSettings() { store.tab = "settings"; store.expanded = true; panel.makeKeyAndOrderFront(nil) }
    func installEditMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit MacAss", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"),
            ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editItem.submenu = edit; menu.addItem(editItem); NSApp.mainMenu = menu
    }
    private func verifyEditing() {
        // Runs inside the real AppKit event loop, isolated from the user's state.
        let testPanel = NotchPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let field = NSTextField(frame: NSRect(x: 10, y: 10, width: 250, height: 30))
        testPanel.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        testPanel.contentView!.addSubview(field); field.stringValue = "Original text"
        testPanel.makeKeyAndOrderFront(nil); field.selectText(nil)
        var passed = false
        if let editor = testPanel.firstResponder as? NSTextView {
            func command(_ key: String) -> Bool {
                let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: testPanel.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)!
                return testPanel.performKeyEquivalent(with: event)
            }
            let copied = command("a") && command("c") && NSPasteboard.general.string(forType: .string) == "Original text"
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString("Pasted text", forType: .string)
            let pasted = command("v") && editor.string == "Pasted text"
            passed = copied && pasted && command("z") && editor.string == "Original text"
        }
        let url = URL(fileURLWithPath: "/tmp/MacAss-editing-result.txt")
        try? (passed ? "passed" : "failed").write(to: url, atomically: true, encoding: .utf8)
        testPanel.orderOut(nil); NSApp.terminate(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { pointer.stop(); store.operation?.cancel(); store.save() }
}

@main struct MacAssApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
