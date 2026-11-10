import AppKit
import SwiftUI
import Combine

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    let music = Music()
    var panel: NotchPanel!
    var status: NSStatusItem!
    var subscription: AnyCancellable?
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
        configureScreen()
        subscription = store.$expanded.removeDuplicates().sink { [weak self] expanded in
            self?.resize(expanded: expanded)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(configureScreen), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        panel.orderFrontRegardless()
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
        let width: CGFloat = expanded ? 460 : notchWidth + 140
        let height: CGFloat = topHeight + (expanded ? 490 : 0)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.22
            panel.animator().setFrame(frame, display: true)
        }
    }
    @objc func openShelf() { store.tab = "tasks"; store.expanded = true; store.pinned = true; panel.makeKeyAndOrderFront(nil) }
    @objc func openSettings() { openShelf(); store.tab = "settings" }
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
