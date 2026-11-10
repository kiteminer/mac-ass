import AppKit
import SwiftUI

@MainActor final class Music: ObservableObject {
    @Published var enabled = true { didSet { UserDefaults.standard.set(!enabled, forKey: "musicDisabled"); refresh() } }
    @Published var title = "Nothing is playing"
    @Published var artist = "Spotify / Apple Music"
    @Published var playing = false
    @Published var message = ""
    @Published var player = "Auto" { didSet { UserDefaults.standard.set(player, forKey: "preferredPlayer"); refresh() } }
    @Published var artwork: NSImage?
    @Published var position = 0.0
    @Published var duration = 1.0
    private var activePlayer = "Spotify"
    private var artworkURL = ""
    private var polling = false
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    init() {
        enabled = !UserDefaults.standard.bool(forKey: "musicDisabled")
        player = UserDefaults.standard.string(forKey: "preferredPlayer") ?? "Auto"
        observer = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
    }
    func refresh() {
        guard !CommandLine.arguments.contains("--verify-scene"), !CommandLine.arguments.contains("--verify-editing") else { return }
        guard enabled, !polling else { return }
        let candidates = (player == "Auto" ? ["Spotify", "Music"] : [player]).filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0 == "Spotify" ? "com.spotify.client" : "com.apple.Music").isEmpty
        }
        guard !candidates.isEmpty else { title = "Open Spotify or Apple Music"; artist = "Your music appears here"; playing = false; artwork = nil; return }
        polling = true
        Task {
            defer { polling = false }
            var selected: (String, [String])?
            for candidate in candidates {
                let art = candidate == "Spotify" ? "artwork url of current track" : "\"\""
                let scale = candidate == "Spotify" ? " / 1000" : ""
                let source = """
                with timeout of 3 seconds
                    tell application "\(candidate)"
                        if player state is stopped then return {"", "", "stopped", "", "0", "1"}
                        return {name of current track, artist of current track, player state as string, \(art), player position as string, ((duration of current track)\(scale)) as string}
                    end tell
                end timeout
                """
                let result = await Self.execute(source)
                guard enabled else { return }
                if result.failed { message = "Allow MacAss in System Settings → Privacy & Security → Automation, then try again."; continue }
                if selected == nil || result.values[safe: 2] == "playing" { selected = (candidate, result.values) }
                if result.values[safe: 2] == "playing" { break }
            }
            guard let (name, values) = selected else { return }
            activePlayer = name; message = ""
            title = values[safe: 0].flatMap { $0.isEmpty ? nil : $0 } ?? "Nothing is playing"
            artist = values[safe: 1] ?? name; playing = values[safe: 2] == "playing"
            position = Double(values[safe: 4] ?? "0") ?? 0; duration = max(1, Double(values[safe: 5] ?? "1") ?? 1)
            let address = values[safe: 3] ?? ""
            if artworkURL != address {
                artworkURL = address; artwork = nil
                if let url = URL(string: address), url.scheme == "https" {
                    var request = URLRequest(url: url); request.timeoutInterval = 8
                    if let (data, _) = try? await URLSession.shared.data(for: request), data.count < 8_000_000, artworkURL == address {
                        artwork = NSImage(data: data)
                    }
                }
            }
        }
    }
    func command(_ command: String) {
        guard enabled, ["playpause", "next track", "previous track"].contains(command) else { return }
        let source = "with timeout of 3 seconds\ntell application \"\(activePlayer)\" to \(command)\nend timeout"
        Task {
            let result = await Self.execute(source)
            if result.failed { message = "Playback control failed. Check Automation permission." }
            refresh()
        }
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
private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension Music {
    func installVerificationScene() {
        title = "Night Drive"; artist = "Instrumental"; playing = true; position = 102; duration = 268
        artwork = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: nil)
    }
}
