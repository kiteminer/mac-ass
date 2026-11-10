import SwiftUI
import AppKit
import NotchCore

private let blue = Color(red: 0.39, green: 0.68, blue: 0.97)

struct NotchView: View {
    @ObservedObject var store: Store
    @ObservedObject var music: Music
    let layout: NotchLayout
    @StateObject private var connection = PlannerConnection()
    @State private var page = 0
    @State private var settingsPage = 0
    @State private var duration = 25
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var size: CGSize { layout.visibleSize(expanded: store.expanded) }
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: layout.notchHeight)
            if store.expanded {
                VStack(alignment: .leading, spacing: 12) {
                    navigation
                    content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    footer
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
                    .frame(width: NotchLayout.width, height: NotchLayout.bodyHeight)
                    .transition(.opacity)
            } else { compact.frame(height: 20).transition(.opacity) }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(.black)
        .mask {
            VStack(spacing: 0) {
                Rectangle().frame(width: layout.notchWidth, height: layout.notchHeight)
                NotchShape(topCornerRadius: store.expanded ? 8 : 4, bottomCornerRadius: store.expanded ? 24 : 12)
                    .frame(width: size.width, height: size.height - layout.notchHeight)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9), value: store.expanded)
        .frame(width: layout.windowFrame.width, height: layout.windowFrame.height, alignment: .top)
        .foregroundStyle(.white).tint(blue).preferredColorScheme(.dark)
        .font(.system(size: 14))
        .buttonStyle(PanelButtonStyle())
        .onExitCommand { store.pinned = false; store.expanded = false }
        .onChange(of: store.tab) { _, _ in page = 0 }
        .onChange(of: store.state.tasks.count) { _, _ in page = 0 }
    }
    private var compact: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 2)
                Circle().trim(from: 0, to: progress).stroke(blue, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
            }.frame(width: 12, height: 12)
            if store.busy { Text("Planning…").font(.system(size: 11, weight: .medium)) }
            else if store.current != nil { Text(store.timeLabel).font(.system(size: 11, weight: .medium, design: .monospaced)) }
            else { Image(systemName: music.playing ? "waveform" : "ellipsis").font(.system(size: 11)) }
        }.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { store.expanded = true }
        .accessibilityLabel(store.busy ? "Planning in background" : "Open MacAss, \(store.timeLabel)")
    }
    private var progress: Double {
        guard let task = store.current, task.minutes > 0 else { return 0 }
        return min(1, max(0, store.state.clock.seconds(at: store.now) / Double(max(task.minutes * 60, 1))))
    }
    private var navigation: some View {
        HStack(spacing: 4) {
            nav("tasks", "Focus", "timer")
            nav("music", "Music", "music.note")
            nav("files", "Files", "tray")
            nav("clipboard", "Clipboard", "doc.on.clipboard")
            Spacer(minLength: 0)
            Button { store.tab = "settings" } label: { Image(systemName: "gearshape").frame(width: 22, height: 22) }.help("Settings")
            Button { store.pinned.toggle() } label: { Image(systemName: store.pinned ? "pin.fill" : "pin").frame(width: 22, height: 22) }.help("Keep panel open")
        }
    }
    private func nav(_ tab: String, _ title: String, _ symbol: String) -> some View {
        Button { store.tab = tab } label: {
            Label(title == "Clipboard" ? "Clips" : title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium)).frame(height: 22)
                .foregroundStyle(store.tab == tab ? blue : .white.opacity(0.65))
        }.help(title).accessibilityLabel(title)
    }
    @ViewBuilder private var content: some View {
        switch store.tab {
        case "music": musicContent
        case "files": filesContent
        case "clipboard": clipboardContent
        case "queue": queueContent
        case "compose": composeContent
        case "subtasks": subtasksContent
        case "settings": settingsContent
        default: focusContent
        }
    }
    private var focusContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let task = store.current {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CURRENT TASK").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text(task.title).font(.system(size: 18, weight: .semibold)).lineLimit(2).help(task.title)
                    }
                    Spacer(minLength: 0)
                    Text(store.timeLabel).font(.system(size: 19, weight: .medium, design: .monospaced))
                    Button(action: store.toggleTimer) { Image(systemName: store.state.clock.deadline == nil ? "play.fill" : "pause.fill").frame(width: 24, height: 28) }.help("Pause or resume")
                }
                progressBar(progress)
                HStack(spacing: 7) {
                    ForEach([5, 10, 15], id: \.self) { n in Button("+\(n)m") { store.addTime(n) } }
                    Spacer()
                    Button("Complete", action: store.complete).foregroundStyle(blue)
                }
                HStack {
                    Button { store.tab = "subtasks" } label: { Label("Subtasks · \(task.subtasks.count)", systemImage: "checklist") }
                    Spacer()
                    Button { store.tab = "queue" } label: { Label("Queue · \(max(0, store.state.tasks.count - 1))", systemImage: "list.bullet") }
                }
                if let next = task.subtasks.first(where: { !$0.done }) {
                    Text(next.title).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("Make room for one thing.").font(.system(size: 21, weight: .semibold)).padding(.top, 12)
                Text("Add a task, or let your local planner organize a list.").foregroundStyle(.secondary).lineLimit(2)
                Button { store.tab = "compose" } label: { Label("New task", systemImage: "plus") }.foregroundStyle(blue)
            }
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.notice.isEmpty {
                Text(store.notice).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).help(store.notice)
            }
            HStack {
                Button { store.tab = "compose" } label: { Label("New task", systemImage: "plus") }
                if let failed = store.failedPlanInput, !store.busy { Button("Retry plan") { store.makePlan(failed) } }
                Spacer()
                if store.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel plan") { store.operation?.cancel() }
                } else {
                    Button { store.tab = "clipboard" } label: { Label("Clipboard · \(store.history.count)", systemImage: "doc.on.clipboard") }
                }
            }.font(.system(size: 12, weight: .medium))
        }
    }
    private var composeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What needs doing?").font(.system(size: 19, weight: .semibold))
            TextField("Write a task or a list…", text: $store.draft, axis: .vertical)
                .lineLimit(2...3).textFieldStyle(.plain).padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit { submit() }
            HStack {
                Picker("Duration", selection: $duration) {
                    Text("No timer").tag(0)
                    ForEach([5, 15, 25, 45, 60], id: \.self) { n in Text("\(n) min").tag(n) }
                }.labelsHidden().frame(width: 100)
                Button("Add task", action: submit).disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Auto plan") {
                    if store.makePlan(store.draft) { store.draft = "" }
                }.disabled(store.busy || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).foregroundStyle(blue)
            }
            Text("Add task uses your chosen time. Auto plan splits and orders your list in the background.").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3)
        }
    }
    private func submit() {
        if store.addManual(store.draft, minutes: duration) { store.draft = ""; store.tab = "tasks" }
    }
    private var subtasksContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Subtasks", count: store.current?.subtasks.count ?? 0)
            if let task = store.current {
                ForEach(paged(task.subtasks, size: 3)) { sub in
                    HStack {
                        Button { store.toggleSubtask(sub.id) } label: {
                            Label(sub.title, systemImage: sub.done ? "checkmark.circle.fill" : "circle").lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Button { store.deleteSubtask(sub.id) } label: { Image(systemName: "trash") }.help("Delete subtask")
                    }
                }
                pager(count: task.subtasks.count, size: 3)
                HStack {
                    TextField("Add a subtask…", text: $store.subtaskDraft).textFieldStyle(.roundedBorder).onSubmit { addSubtask() }
                    Button("Add", action: addSubtask)
                }
            } else { Text("Add a task first.").foregroundStyle(.secondary) }
        }
    }
    private func addSubtask() {
        if store.addSubtask(store.subtaskDraft) { store.subtaskDraft = "" }
    }
    private var queueContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Task queue", count: max(0, store.state.tasks.count - 1))
            let tasks = Array(store.state.tasks.dropFirst())
            if tasks.isEmpty { Text("No queued tasks.").foregroundStyle(.secondary) }
            ForEach(paged(tasks, size: 3)) { task in
                HStack {
                    Text(task.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).help(task.title)
                    Button("Start") { store.activateTask(task.id) }.help("Pause current task and start this task")
                    Button { store.deleteTask(task.id) } label: { Image(systemName: "trash") }.help("Delete task")
                }
            }
            pager(count: tasks.count, size: 3)
        }
    }
    private var filesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Saved items", count: store.state.shelf.count)
                Spacer()
                Button("Paste") { store.pasteToShelf() }
                Button { chooseFiles() } label: { Image(systemName: "plus") }.help("Add files")
            }
            if store.state.shelf.isEmpty {
                Label("Drop files or text onto the notch", systemImage: "tray.and.arrow.down")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 110)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 10) {
                    ForEach(paged(store.state.shelf, size: 3)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = item.url {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 38, height: 38)
                            } else { Image(systemName: "quote.opening").font(.system(size: 28)).foregroundStyle(blue) }
                            Text(item.name).font(.system(size: 12)).lineLimit(2).frame(height: 32, alignment: .top)
                            HStack {
                                Button { if let text = item.text { store.copy(text) } else if let url = item.url { NSWorkspace.shared.activateFileViewerSelecting([url]) } } label: { Image(systemName: item.text != nil ? "doc.on.doc" : "folder") }
                                Button { store.remove(item) } label: { Image(systemName: "trash") }
                            }
                        }.padding(10).frame(width: 108, height: 146, alignment: .topLeading)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            .onDrag { item.url.flatMap({ NSItemProvider(contentsOf: $0) }) ?? NSItemProvider(object: (item.text ?? "") as NSString) }
                    }
                }
            }
            pager(count: store.state.shelf.count, size: 3)
        }
    }
    private var clipboardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Clipboard", count: store.history.count)
                Spacer()
                Button("Clear") { store.history = [] }
                Button(store.clipboardEnabled ? "Pause" : "Enable") { store.clipboardEnabled.toggle() }
            }
            if !store.clipboardEnabled {
                Text("History is paused. Enable it to capture copied text.").foregroundStyle(.secondary)
            } else if store.history.isEmpty {
                Text("Copy text in any app. It appears here automatically.").foregroundStyle(.secondary)
                Button("Capture current clipboard") { store.captureClipboard(force: true) }
            }
            ForEach(paged(store.history, size: 3), id: \.self) { text in
                HStack {
                    Button { store.copy(text) } label: { Text(text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
                    Button { store.addText(text) } label: { Image(systemName: "pin") }.help("Save")
                    Button { store.history.removeAll { $0 == text } } label: { Image(systemName: "trash") }.help("Delete")
                }.onDrag { NSItemProvider(object: text as NSString) }
            }
            pager(count: store.history.count, size: 3)
        }
    }
    private var musicContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Group {
                    if let image = music.artwork { Image(nsImage: image).resizable().scaledToFill() }
                    else { Image(systemName: "music.note").font(.system(size: 30)).foregroundStyle(blue) }
                }.frame(width: 76, height: 76).background(.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 8) {
                    Text(music.title).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                    HStack {
                        Text(music.artist).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 0)
                        TimelineView(.animation(minimumInterval: 0.15, paused: !music.playing || reduceMotion)) { context in
                            HStack(spacing: 2) {
                                ForEach(0..<5) { i in
                                    Capsule().fill(blue).frame(width: 3, height: music.playing ? 4 + 12 * abs(sin(context.date.timeIntervalSinceReferenceDate * 3 + Double(i))) : 4)
                                }
                            }.frame(width: 24, height: 18)
                        }.accessibilityLabel(music.playing ? "Playing" : "Paused")
                    }
                    HStack(spacing: 18) {
                        Button { music.command("previous track") } label: { Image(systemName: "backward.fill") }
                        Button { music.command("playpause") } label: { Image(systemName: music.playing ? "pause.fill" : "play.fill") }
                        Button { music.command("next track") } label: { Image(systemName: "forward.fill") }
                    }.disabled(!music.enabled)
                }
            }
            progressBar(min(1, max(0, music.position / music.duration)))
            if !music.message.isEmpty { Text(music.message).font(.system(size: 12)).lineLimit(2).foregroundStyle(.secondary) }
            Button { store.tab = "tasks" } label: {
                HStack {
                    Text(store.current?.title ?? "Open focus workspace").lineLimit(1)
                    Spacer()
                    if store.current != nil { Text(store.timeLabel).monospacedDigit() }
                    Image(systemName: "chevron.right")
                }.frame(maxWidth: .infinity)
            }
        }
    }
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Settings").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(settingsPage == 0 ? "Music & privacy →" : "← Local planner") { settingsPage = 1 - settingsPage }
            }
            if settingsPage == 0 {
                Picker("Server", selection: $store.state.planner.openAICompatible) {
                    Text("Ollama").tag(false); Text("MLX / compatible").tag(true)
                }.onChange(of: store.state.planner.openAICompatible) { _, _ in connection.models = [] }
                TextField("http://127.0.0.1:11434", text: $store.state.planner.endpoint).textFieldStyle(.roundedBorder)
                TextField("Exact installed model name", text: $store.state.planner.model).textFieldStyle(.roundedBorder)
                HStack {
                    Button(connection.checking ? "Checking…" : "Check connection") { connection.check(store.state.planner) }.disabled(connection.checking)
                    Menu("Models") { ForEach(connection.models, id: \.self) { name in Button(name) { store.state.planner.model = name; store.save() } } }
                    Button("Save") { store.save(); store.notice = "Settings saved." }
                }
                Text(connection.status).font(.system(size: 12)).lineLimit(2)
            } else {
                Toggle("Capture text clipboard history", isOn: $store.clipboardEnabled)
                Text("Kept in memory until quit. Sensitive clipboard markers are excluded.").font(.system(size: 12)).foregroundStyle(.secondary)
                Toggle("Read and control music", isOn: $music.enabled)
                Picker("Player", selection: $music.player) {
                    Text("Automatic").tag("Auto"); Text("Spotify").tag("Spotify"); Text("Apple Music").tag("Music")
                }
                Text("Allow MacAss in System Settings → Privacy & Security → Automation.").font(.system(size: 12)).foregroundStyle(.secondary)
                Button("Quit MacAss") { NSApp.terminate(nil) }
            }
        }
    }
    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(blue).frame(width: geometry.size.width * value)
            }
        }.frame(height: 4)
    }
    private func sectionTitle(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)").font(.system(size: 17, weight: .semibold))
    }
    private func paged<T>(_ values: [T], size: Int) -> [T] {
        let p = PageBounds.page(page, count: values.count, size: size)
        return Array(values.dropFirst(p * size).prefix(size))
    }
    private func pager(count: Int, size: Int) -> some View {
        let p = PageBounds.page(page, count: count, size: size)
        return HStack {
            if count > size {
                Button("Previous") { page = max(0, p - 1) }.disabled(p == 0)
                Text("\(p + 1) / \((count + size - 1) / size)").font(.system(size: 12)).foregroundStyle(.secondary)
                Button("Next") { page = p + 1 }.disabled((p + 1) * size >= count)
            }
        }
    }
    private func chooseFiles() {
        store.dialogOpen = true
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.begin { response in
            Task { @MainActor in
                store.dialogOpen = false
                if response == .OK { panel.urls.forEach(store.addFile) }
            }
        }
    }
}

private struct PanelButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 7).padding(.vertical, 6)
            .background(.white.opacity(configuration.isPressed ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? 1 : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}
