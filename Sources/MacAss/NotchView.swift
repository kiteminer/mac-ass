import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var store: Store
    @ObservedObject var music: Music
    var notchWidth: CGFloat
    var topHeight: CGFloat
    @State private var draft = ""
    @State private var minutes = 25
    @State private var submittedDraft = ""
    @State private var dropTarget = false
    @State private var closeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accent = Color(red: 0.43, green: 0.69, blue: 0.94)
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: store.current == nil ? "tray" : "timer")
                    .foregroundStyle(accent).frame(width: 64)
                Spacer(minLength: notchWidth)
                Text(store.current == nil ? "Shelf" : store.timeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 76)
            }
            .frame(height: topHeight)
            .contentShape(Rectangle())
            .onTapGesture { store.expanded.toggle() }
            .help("Expand or collapse shelf")
            if store.expanded {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        tabButton("Tasks & clipboard", "tasks", "square.stack")
                        tabButton("Music", "music", "music.note")
                        Spacer(minLength: 0)
                        Button { store.tab = "settings" } label: { Image(systemName: "gearshape") }.help("Settings")
                        Button { store.pinned.toggle() } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }.help("Pin panel")
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if store.tab == "music" { musicView }
                            else if store.tab == "settings" { settingsView }
                            else { taskView; Divider(); shelfView; Divider(); composer }
                            if !store.notice.isEmpty {
                                Text(store.notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                }
                .padding(20).frame(height: 490)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: store.expanded ? 460 : notchWidth + 140)
        .background(dropTarget ? Color(red: 0.04, green: 0.09, blue: 0.15) : Color.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .overlay(alignment: .bottom) {
            if dropTarget {
                Label("Drop to save", systemImage: "plus.circle.fill")
                    .padding(18).frame(maxWidth: .infinity).background(accent.opacity(0.2)).allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white).tint(accent).preferredColorScheme(.dark)
        .buttonStyle(.borderless)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: store.expanded)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: dropTarget)
        .onHover { inside in
            closeTask?.cancel()
            closeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(inside ? 180 : 600))
                guard !Task.isCancelled else { return }
                if inside { store.expanded = true }
                else if !store.pinned && !store.busy && draft.isEmpty && !dropTarget { store.expanded = false }
            }
        }
        .onDrop(of: [UTType.fileURL, UTType.utf8PlainText], isTargeted: $dropTarget, perform: acceptDrop)
        .onChange(of: store.plansAdded) { _, _ in if draft == submittedDraft { draft = "" } }
        .onChange(of: dropTarget) { _, value in if value { store.expanded = true; store.tab = "tasks" } }
    }
    private func tabButton(_ title: String, _ value: String, _ icon: String) -> some View {
        Button { store.tab = value } label: {
            Label(title, systemImage: icon).font(.caption.weight(.medium)).padding(7)
                .background(store.tab == value ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
    }
    private var taskView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOW").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if let current = store.current {
                HStack {
                    Text(current.title).font(.headline).lineLimit(3)
                    Spacer()
                    Text(store.timeLabel).font(.system(.title3, design: .monospaced)).contentTransition(.numericText())
                    Button(action: store.toggleTimer) {
                        Image(systemName: store.state.clock.deadline == nil ? "play.fill" : "pause.fill").padding(9).background(.white.opacity(0.1), in: Circle())
                    }.help("Start / pause")
                }
                ProgressView(value: min(1, store.state.clock.seconds(at: store.now) / Double(max(1, current.minutes * 60))))
                HStack {
                    ForEach([5, 10, 15], id: \.self) { n in
                        Button("+\(n) min") { store.addTime(n) }.buttonStyle(.bordered).controlSize(.small)
                    }
                    Spacer()
                    Button("Complete", action: store.complete).buttonStyle(.borderedProminent).controlSize(.small)
                }
                ForEach(current.subtasks) { sub in
                    Button {
                        guard let index = store.state.tasks.first?.subtasks.firstIndex(where: { $0.id == sub.id }) else { return }
                        store.state.tasks[0].subtasks[index].done.toggle(); store.save()
                    } label: {
                        Label(sub.title, systemImage: sub.done ? "checkmark.square.fill" : "square")
                            .foregroundStyle(sub.done ? .secondary : .primary).font(.subheadline)
                    }
                }
                if store.state.tasks.count > 1 {
                    DisclosureGroup("Up next · \(store.state.tasks.count - 1)") {
                        ForEach(Array(store.state.tasks.dropFirst())) { task in
                            HStack {
                                Text(task.title).lineLimit(2); Spacer(); Text("\(task.minutes) min").foregroundStyle(.secondary)
                                Button {
                                    store.state.tasks.removeAll { $0.id == task.id }; store.save()
                                } label: { Image(systemName: "xmark") }.help("Remove from queue")
                            }.font(.caption).padding(.vertical, 5)
                        }
                    }.font(.caption)
                }
            } else {
                Text("What are we doing today?").font(.title3.weight(.semibold))
                Text("Add a task or paste your to-do list below.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var shelfView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shelf").font(.headline)
                Text("\(store.state.shelf.count)").foregroundStyle(.secondary)
                Spacer()
                Button { chooseFiles() } label: { Image(systemName: "plus") }.help("Add files")
                Button("Paste") {
                    let pb = NSPasteboard.general
                    if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { urls.forEach(store.addFile) }
                    else if let text = pb.string(forType: .string) { store.addText(text) }
                }.font(.caption)
            }
            if store.state.shelf.isEmpty {
                Text("Drop a file or text here, then drag it into another app.")
                    .font(.caption).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.state.shelf) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = item.url {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().frame(width: 36, height: 36)
                            } else { Image(systemName: "quote.opening").font(.title2).foregroundStyle(accent) }
                            Text(item.name).font(.caption).lineLimit(2).frame(height: 30, alignment: .top)
                        }.padding(10).frame(width: 100, height: 88, alignment: .leading)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .onDrag {
                            if let url = item.url { return NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                            return NSItemProvider(object: (item.text ?? "") as NSString)
                        }
                        .onTapGesture {
                            if let text = item.text { store.copy(text); store.notice = "Copied." }
                            else if let url = item.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                        }
                        .contextMenu {
                            Button("Remove from shelf") { store.remove(item) }
                        }
                    }
                }
            }
            DisclosureGroup("Clipboard history · \(store.history.count)") {
                if !store.clipboardEnabled {
                    Button("Enable text history") { store.clipboardEnabled = true }
                    Text("Kept in memory until you quit. Do not copy secrets here.").font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button("Clear") { store.history = [] }
                        Spacer()
                        Button("Disable") { store.clipboardEnabled = false }
                    }.font(.caption)
                    ForEach(Array(store.history.enumerated()), id: \.offset) { _, text in
                        HStack {
                            Button { store.copy(text) } label: { Text(text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
                            Button { store.addText(text) } label: { Image(systemName: "pin") }.help("Save to shelf")
                        }.font(.caption).padding(.vertical, 5).onDrag { NSItemProvider(object: text as NSString) }
                    }
                }
            }.font(.caption)
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Clean up, update resume (experience, tools)…", text: $draft, axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.roundedBorder)
            HStack {
                Picker("Minutes", selection: $minutes) {
                    Text("No timer").tag(0)
                    ForEach([5, 15, 25, 45, 60], id: \.self) { n in Text("\(n) min").tag(n) }
                }.frame(width: 105)
                Button("Add") { store.addManual(draft, minutes: minutes); draft = "" }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if store.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { store.operation?.cancel() }
                } else {
                    Button("Plan list") { submittedDraft = draft; store.makePlan(draft) }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.font(.caption)
        }
    }
    private var musicView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "waveform").font(.system(size: 38)).foregroundStyle(accent)
                    .frame(width: 76, height: 76).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 7) {
                    Text(music.title).font(.title3.weight(.semibold)).lineLimit(2)
                    Text(music.artist).font(.caption).foregroundStyle(.secondary)
                }
            }
            if music.enabled {
                HStack(spacing: 32) {
                    Button { music.command("previous track") } label: { Image(systemName: "backward.fill") }
                    Button { music.command("playpause") } label: { Image(systemName: music.playing ? "pause.fill" : "play.fill").font(.title) }
                    Button { music.command("next track") } label: { Image(systemName: "forward.fill") }
                }.frame(maxWidth: .infinity)
            } else {
                Button("Connect a player in settings") { store.tab = "settings" }
            }
            if !music.message.isEmpty { Text(music.message).font(.caption).foregroundStyle(.secondary) }
            Divider()
            Button { store.tab = "tasks" } label: {
                HStack {
                    Image(systemName: "square.stack")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.current?.title ?? "Tasks & clipboard").lineLimit(2)
                        Text("Open shelf and clipboard history").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.current != nil { Text(store.timeLabel).monospacedDigit() }
                    Image(systemName: "chevron.right")
                }.padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            if store.current != nil {
                HStack { ForEach([5, 10, 15], id: \.self) { n in Button("+\(n) min") { store.addTime(n) }.buttonStyle(.bordered) } }
            }
        }
    }
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.title2.weight(.semibold))
            Text("Local planner").font(.headline)
            Picker("Protocol", selection: $store.state.planner.openAICompatible) {
                Text("Ollama").tag(false); Text("MLX / OpenAI-compatible").tag(true)
            }
            TextField("Address: http://127.0.0.1:11434", text: $store.state.planner.endpoint).textFieldStyle(.roundedBorder)
            TextField("Model name on the server", text: $store.state.planner.model).textFieldStyle(.roundedBorder)
            Text("Localhost only. For MLX, use your server port, such as 8080. The /v1 path is added automatically. Your list is sent only when you click Plan list.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Save settings") { store.save(); store.notice = "Settings saved." }
            Divider()
            Toggle("Text clipboard history", isOn: $store.clipboardEnabled)
            Picker("Player", selection: $music.player) { Text("Apple Music").tag("Music"); Text("Spotify").tag("Spotify") }
            Toggle("Music controls", isOn: $music.enabled).onChange(of: music.enabled) { _, enabled in if enabled { music.refresh() } }
            Text("When enabled, macOS requests permission to control the selected player. Other players are not supported yet.").font(.caption).foregroundStyle(.secondary)
            Button("Quit MacAss") { NSApp.terminate(nil) }.foregroundStyle(.secondary)
        }
    }
    private func chooseFiles() {
        store.pinned = true
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.begin { result in
            if result == .OK { Task { @MainActor in panel.urls.forEach(store.addFile) } }
        }
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        store.tab = "tasks"; store.expanded = true
        for provider in providers.prefix(20) {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, _ in
                    let url = (value as? URL) ?? (value as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    if let url { Task { @MainActor in store.addFile(url) } }
                }
            } else {
                provider.loadObject(ofClass: NSString.self) { value, _ in
                    if let text = value as? String { Task { @MainActor in store.addText(text) } }
                }
            }
        }
        return !providers.isEmpty
    }
}
