import AppKit
import SwiftUI
import Combine
import NotchCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
    var panel: NotchPanel!
    var status: NSStatusItem!
    var subscription: AnyCancellable?
    var pointerTimer: Timer?
    var outsideSince: Date?
    var notchWidth: CGFloat = 180
    var topHeight: CGFloat = 32
    var screen: NSScreen?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "MacAss")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open shelf", action: #selector(openShelf), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        status.menu = menu
        installEditMenu()
        configureScreen()
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.store.expanded, !self.store.pinned else { return }
                if self.panel.frame.contains(NSEvent.mouseLocation) { self.outsideSince = nil }
                else if let since = self.outsideSince, Date().timeIntervalSince(since) > 0.7 {
                    self.store.expanded = false; self.panel.resignKey(); self.outsideSince = nil
                } else if self.outsideSince == nil { self.outsideSince = Date() }
            }
        }
        subscription = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { guard let self else { return }; self.resize(expanded: self.store.expanded) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(configureScreen), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        panel.orderFrontRegardless()
        if CommandLine.arguments.contains("--show-window") { openShelf(); store.pinned = true }
    }
    @objc func configureScreen() {
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        guard let screen else { return }
        topHeight = max(28, screen.safeAreaInsets.top)
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = max(120, right.minX - left.maxX)
        } else { notchWidth = 120 }
        panel.contentView = NSHostingView(rootView: NotchView(store: store, music: music, notchWidth: notchWidth, topHeight: topHeight))
        resize(expanded: store.expanded)
    }
    func resize(expanded: Bool) {
        guard let panel, let screen else { return }
        if !expanded { panel.resignKey() }
        let width: CGFloat = expanded ? 400 : notchWidth + 88
        let height: CGFloat = topHeight + (expanded ? PanelLayout.height(tab: store.tab, hasTask: store.current != nil) : 0)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        guard panel.frame != frame else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.22
            panel.animator().setFrame(frame, display: true)
        }
    }
    @objc func openShelf() { store.tab = "tasks"; store.expanded = true; panel.makeKeyAndOrderFront(nil) }
    @objc func openSettings() { openShelf(); store.tab = "settings" }
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
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { store.operation?.cancel(); store.save() }
}

@main struct MacAssApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
