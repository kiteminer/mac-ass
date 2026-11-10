import AppKit
import SwiftUI

@MainActor final class Music: ObservableObject {
    @Published var enabled = false
    @Published var title = "Music"
    @Published var artist = "Apple Music / Spotify"
    @Published var playing = false
    @Published var message = ""
    @Published var player = "Music"
    private var polling = false
    private var timer: Timer?
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        guard enabled, !polling else { return }
        let bundle = player == "Spotify" ? "com.spotify.client" : "com.apple.Music"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty else {
            title = "Open \(player)"; playing = false; return
        }
        polling = true
        let source = """
        tell application "\(player)"
            if player state is stopped then return {"", "", "stopped"}
            return {name of current track, artist of current track, player state as string}
        end tell
        """
        Task {
            let result = await Self.execute(source)
            polling = false
            guard enabled else { return }
            if result.failed { message = "Allow control in System Settings → Privacy & Security → Automation."; return }
            message = ""
            title = result.values.first.flatMap { $0.isEmpty ? nil : $0 } ?? "Nothing is playing"
            artist = result.values.count > 1 ? result.values[1] : ""
            playing = result.values.last == "playing"
        }
    }
    func command(_ command: String) {
        guard enabled, ["playpause", "next track", "previous track"].contains(command) else { return }
        let source = "tell application \"\(player)\" to \(command)"
        Task { _ = await Self.execute(source); refresh() }
    }
    nonisolated private static func execute(_ source: String) async -> (values: [String], failed: Bool) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var error: NSDictionary?
                let reply = NSAppleScript(source: source)?.executeAndReturnError(&error)
                var values: [String] = []
                if let reply, reply.numberOfItems > 0 {
                    for i in 1...reply.numberOfItems { values.append(reply.atIndex(i)?.stringValue ?? "") }
                }
                continuation.resume(returning: (values, error != nil))
            }
        }
    }
}
