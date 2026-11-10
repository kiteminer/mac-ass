import SwiftUI
import AppKit
import UniformTypeIdentifiers
import NotchCore

struct NotchView: View {
    @ObservedObject var store: Store
    @ObservedObject var music: Music
    var notchWidth: CGFloat
    var topHeight: CGFloat
    @State private var draft = ""
    @State private var historyPage = 0
    @State private var shelfPage = 0
    @State private var queuePage = 0
    @State private var subtaskPage = 0
    @State private var subtaskDraft = ""
    @StateObject private var connection = PlannerConnection()
    @State private var minutes = 25
    @State private var submittedDraft = ""
    @State private var dropTarget = false
    @State private var closeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accent = Color(red: 0.43, green: 0.69, blue: 0.94)
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 2.5)
                    Circle().trim(from: 0, to: store.current == nil ? 0 : min(1, store.state.clock.seconds(at: store.now) / Double(max(1, (store.current?.minutes ?? 25) * 60))))
                        .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
                    if store.busy { ProgressView().controlSize(.mini) }
                }.frame(width: 16, height: 16).frame(width: 40)
                Spacer(minLength: notchWidth)
                Text(store.current == nil ? (music.playing ? "♫" : "") : store.timeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 48)
            }
            .frame(height: topHeight)
            .contentShape(Rectangle())
            .onTapGesture { store.expanded.toggle() }
            .help("Expand or collapse shelf")
            if store.expanded {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        tabButton("Focus", "tasks", "square.stack")
                        tabButton("Music", "music", "music.note")
                        Spacer(minLength: 0)
                        Button { store.tab = "settings" } label: { Image(systemName: "gearshape") }.help("Settings")
                        Button { store.pinned.toggle() } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }.help("Pin panel")
                    }
                    VStack {
                        VStack(alignment: .leading, spacing: 10) {
                            if store.tab == "music" { musicView }
                            else if store.tab == "settings" { settingsView }
                            else { composer; if store.current != nil { taskView }; Divider(); shelfView }
                            if !store.notice.isEmpty {
                                Text(store.notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                }
                .padding(.horizontal, 16).padding(.bottom, 14).padding(.top, 8)
                .frame(height: PanelLayout.height(tab: store.tab, hasTask: store.current != nil))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: store.expanded ? 400 : notchWidth + 88)
        .background(dropTarget ? Color(red: 0.04, green: 0.09, blue: 0.15) : Color.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .overlay(alignment: .bottom) {
            if dropTarget {
                Label("Drop to save", systemImage: "plus.circle.fill")
                    .padding(18).frame(maxWidth: .infinity).background(accent.opacity(0.2)).allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white).tint(accent).preferredColorScheme(.dark)
        .buttonStyle(.bordered)
        .font(.system(size: 14))

        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: dropTarget)
        .onHover { inside in
            closeTask?.cancel()
            closeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(inside ? 0 : 600))
                guard !Task.isCancelled else { return }
                if inside { store.expanded = true }
                else if !store.pinned && !dropTarget { store.expanded = false }
            }
        }
        .onDrop(of: [UTType.fileURL, UTType.utf8PlainText], isTargeted: $dropTarget, perform: acceptDrop)
        .onExitCommand { store.pinned = false; store.expanded = false }
        .onChange(of: store.expanded) { _, open in
            if open && store.current == nil && music.playing && draft.isEmpty && store.tab != "settings" { store.tab = "music" }
        }
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
            if store.current != nil { Text("NOW").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) }
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
                ForEach(Array(current.subtasks.dropFirst(subtaskPage * 3).prefix(3))) { sub in
                    Button {
                        guard let index = store.state.tasks.first?.subtasks.firstIndex(where: { $0.id == sub.id }) else { return }
                        store.state.tasks[0].subtasks[index].done.toggle(); store.save()
                    } label: {
                        Label(sub.title, systemImage: sub.done ? "checkmark.square.fill" : "square")
                            .foregroundStyle(sub.done ? .secondary : .primary).font(.subheadline)
                    }
                }
                pager(page: $subtaskPage, count: current.subtasks.count)
                HStack {
                    TextField("Add a subtask…", text: $subtaskDraft)
                        .textFieldStyle(.plain).font(.caption)
                        .onSubmit { addSubtask() }
                    Button(action: addSubtask) { Image(systemName: "plus.circle") }.help("Add subtask")
                }.padding(8).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                if store.state.tasks.count > 1 {
                    pager(page: $queuePage, count: store.state.tasks.count - 1)
                    DisclosureGroup("Queued tasks · \(store.state.tasks.count - 1)") {
                        ForEach(Array(store.state.tasks.dropFirst(1 + queuePage * 3).prefix(3))) { task in
                            HStack {
                                Text(task.title).lineLimit(2); Spacer(); Text("\(task.minutes) min").foregroundStyle(.secondary)
                                Button {
                                    store.state.tasks.removeAll { $0.id == task.id }; store.save()
                                } label: { Image(systemName: "xmark") }.help("Remove from queue")
                            }.font(.caption).padding(.vertical, 5)
                        }
                    }.font(.caption)
                }
            }
        }
    }
    private var shelfView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved").font(.caption.weight(.semibold))
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
                Label("Drop files or text here", systemImage: "tray.and.arrow.down")
                    .font(.caption).foregroundStyle(.secondary).padding(10).frame(maxWidth: .infinity)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            if !store.state.shelf.isEmpty {
            VStack {
                HStack(spacing: 8) {
                    ForEach(Array(store.state.shelf.dropFirst(shelfPage * 3).prefix(3))) { item in
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
            }
            pager(page: $shelfPage, count: store.state.shelf.count)
            DisclosureGroup("Clipboard history · \(store.history.count)") {
                if !store.clipboardEnabled {
                    Button("Enable text history") { store.clipboardEnabled = true }
                    Text("Kept in memory until you quit. Do not copy secrets here.").font(.caption).foregroundStyle(.secondary)
                } else {
                    pager(page: $historyPage, count: store.history.count)
                    HStack {
                        Button("Clear") { store.history = [] }
                        Spacer()
                        Button("Disable") { store.clipboardEnabled = false }
                    }.font(.caption)
                    ForEach(Array(store.history.enumerated()).dropFirst(historyPage * 3).prefix(3), id: \.offset) { _, text in
                        HStack {
                            Button { store.copy(text) } label: { Text(text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
                            Button { store.addText(text) } label: { Image(systemName: "pin") }.help("Save to shelf")
                            Button { store.history.removeAll { $0 == text } } label: { Image(systemName: "trash") }.help("Delete entry")
                        }.font(.caption).padding(.vertical, 5).onDrag { NSItemProvider(object: text as NSString) }
                    }
                }
            }.font(.caption)
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a task…", text: $draft)
                .textFieldStyle(.plain).padding(10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit { submitTask() }
            HStack {
                Picker("Minutes", selection: $minutes) {
                    Text("No timer").tag(0)
                    ForEach([5, 15, 25, 45, 60], id: \.self) { n in Text("\(n) min").tag(n) }
                }.labelsHidden().frame(width: 90)
                Button("Add", action: submitTask).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if store.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { store.operation?.cancel() }
                } else {
                    Button("Auto plan") { submittedDraft = draft; store.makePlan(draft); draft = "" }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.font(.caption)
        }
    }
    private var musicView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Group {
                    if let artwork = music.artwork { Image(nsImage: artwork).resizable().scaledToFill() }
                    else { Image(systemName: "music.note").font(.system(size: 26)).foregroundStyle(accent) }
                }.frame(width: 64, height: 64).background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(music.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(music.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 22) {
                        Button { music.command("previous track") } label: { Image(systemName: "backward.fill") }.help("Previous track")
                        Button { music.command("playpause") } label: { Image(systemName: music.playing ? "pause.fill" : "play.fill") }.help("Play or pause")
                        Button { music.command("next track") } label: { Image(systemName: "forward.fill") }.help("Next track")
                    }.disabled(!music.enabled)
                }
                Spacer(minLength: 0)
                TimelineView(.animation(minimumInterval: 0.15, paused: !music.playing || reduceMotion)) { context in
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<5) { i in
                            Capsule().fill(accent.opacity(0.8)).frame(width: 3,
                                height: music.playing ? 5 + 15 * abs(sin(context.date.timeIntervalSinceReferenceDate * 3 + Double(i))) : 4)
                        }
                    }.frame(width: 25, height: 24)
                }.accessibilityLabel(music.playing ? "Playing" : "Paused")
            }
            ProgressView(value: min(1, max(0, music.position / music.duration))).tint(accent)
            if !music.enabled { Button("Enable music") { music.enabled = true } }
            if !music.message.isEmpty { Text(music.message).font(.caption).foregroundStyle(.secondary) }
            Button { store.tab = "tasks" } label: {
                HStack {
                    Image(systemName: "square.stack")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.current?.title ?? "Open workspace").font(.caption.weight(.medium)).lineLimit(1)
                        Text("Tasks, files & clipboard").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.current != nil { Text(store.timeLabel).font(.caption).monospacedDigit() }
                    Image(systemName: "chevron.right").font(.caption)
                }.padding(10).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
            if store.current != nil {
                HStack { ForEach([5, 10, 15], id: \.self) { n in Button("+\(n) min") { store.addTime(n) }.buttonStyle(.bordered).controlSize(.small) } }
            }
        }
    }
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.title2.weight(.semibold))
            Text("Local planner").font(.headline)
            Text("Already using ollama run? Keep it running. Use Ollama below, click Check connection, then choose your installed model.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(connection.checking ? "Checking…" : "Check connection") { connection.check(store.state.planner) }.disabled(connection.checking)
                Button("Copy server command") { store.copy("ollama serve") }
            }.font(.caption)
            Text(connection.status).font(.caption).foregroundStyle(.secondary)
            if !connection.models.isEmpty {
                Menu("Choose installed model") {
                    ForEach(connection.models, id: \.self) { name in
                        Button(name) { store.state.planner.model = name; store.save() }
                    }
                }
            }
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
            Picker("Player", selection: $music.player) { Text("Automatic").tag("Auto"); Text("Apple Music").tag("Music"); Text("Spotify").tag("Spotify") }
            Toggle("Music controls", isOn: $music.enabled).onChange(of: music.enabled) { _, enabled in if enabled { music.refresh() } }
            Text("When enabled, macOS requests permission to control the selected player. Other players are not supported yet.").font(.caption).foregroundStyle(.secondary)
            Button("Quit MacAss") { NSApp.terminate(nil) }.foregroundStyle(.secondary)
        }
    }
    private func pager(page: Binding<Int>, count: Int) -> some View {
        HStack {
            if count > 3 {
                Button("Previous") { page.wrappedValue = max(0, page.wrappedValue - 1) }.disabled(page.wrappedValue == 0)
                Text("Page \(page.wrappedValue + 1)").font(.caption)
                Button("Next") { page.wrappedValue += 1 }.disabled((page.wrappedValue + 1) * 3 >= count)
            }
        }
    }
    private func submitTask() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if (try? TaskParser.parse(draft)) != nil { store.addManual(draft, minutes: minutes); draft = "" }
        else { store.notice = "Enter 1–20 tasks, up to 4,000 characters." }
    }
    private func addSubtask() { store.addSubtask(subtaskDraft); subtaskDraft = "" }
    private func chooseFiles() {
        let wasPinned = store.pinned
        store.pinned = true
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.begin { result in
            Task { @MainActor in
                store.pinned = wasPinned
                if result == .OK { panel.urls.forEach(store.addFile) }
            }
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
