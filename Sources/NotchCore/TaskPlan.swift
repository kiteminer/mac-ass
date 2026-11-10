import Foundation

public struct Subtask: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var title: String
    public var done = false
    public init(_ title: String) { self.title = title }
}

public struct FocusTask: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var title: String
    public var subtasks: [Subtask]
    public var minutes: Int
    public var explicitDuration: Bool
    public var location: String
    public init(title: String, subtasks: [Subtask] = [], minutes: Int = 25,
                explicitDuration: Bool = false, location: String = "unknown") {
        self.title = title; self.subtasks = subtasks; self.minutes = minutes
        self.explicitDuration = explicitDuration; self.location = location
    }
}

public enum PlanError: Error { case invalidInput, invalidResponse, invalidEndpoint, server(Int) }

public enum TaskParser {
    // Only top-level separators split tasks; parentheses remain attached to their parent.
    public static func split(_ input: String) -> [String] {
        var depth = 0, current = "", result: [String] = []
        for c in input {
            if c == "(" { depth += 1 }
            if c == ")" { depth = max(0, depth - 1) }
            if depth == 0 && [",", ";", "\n"].contains(c) {
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(current) }
                current = ""
            } else { current.append(c) }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(current) }
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    public static func homeFirst(_ input: String) -> Bool {
        let lower = input.lowercased()
        return lower.contains("home first")
    }
    public static func parse(_ input: String) throws -> [FocusTask] {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, input.count <= 4000 else {
            throw PlanError.invalidInput
        }
        let tasks = split(input).filter {
            let s = $0.lowercased()
            return !["home first"].contains(s)
        }.map { source -> FocusTask in
            var title = source, children: [Subtask] = []
            if let start = source.firstIndex(of: "("), let end = source.lastIndex(of: ")"), start < end {
                children = split(String(source[source.index(after: start)..<end])).prefix(12).map(Subtask.init)
                title = String(source[..<start]) + String(source[source.index(after: end)...])
            }
            let lower = title.lowercased()
            var minutes = 25, explicit = false
            if let range = lower.range(of: #"\b\d{1,3}\s*(minutes?|mins?|m)\b"#, options: .regularExpression),
               let n = Int(lower[range].prefix(while: { $0.isNumber })) {
                minutes = min(180, max(5, n)); explicit = true
            }
            let outside = ["outside", "shop", "walk", "pharmacy", "errand"].contains { lower.contains($0) }
            let home = ["resume", "clean", "home", "email", "write"].contains { lower.contains($0) }
            return FocusTask(title: String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)),
                             subtasks: children, minutes: minutes, explicitDuration: explicit,
                             location: outside ? "outside" : home ? "home" : "unknown")
        }
        guard !tasks.isEmpty, tasks.count <= 20, tasks.allSatisfy({ !$0.title.isEmpty }) else { throw PlanError.invalidInput }
        return enforceConstraints(tasks, input: input)
    }
    public static func enforceConstraints(_ tasks: [FocusTask], input: String) -> [FocusTask] {
        guard homeFirst(input) else { return tasks }
        return tasks.filter { $0.location != "outside" } + tasks.filter { $0.location == "outside" }
    }
}

public struct PlanReply: Codable {
    public struct Entry: Codable { public let id: String; public let minutes: Int }
    public let tasks: [Entry]
}

public enum PlanValidator {
    public static func apply(_ data: Data, to originals: [FocusTask], input: String) throws -> [FocusTask] {
        guard data.count <= 32_768 else { throw PlanError.invalidResponse }
        let reply = try JSONDecoder().decode(PlanReply.self, from: data)
        let ids = reply.tasks.map(\.id)
        guard ids.count == originals.count, Set(ids).count == ids.count,
              Set(ids) == Set(originals.map { $0.id.uuidString }),
              reply.tasks.allSatisfy({ (5...180).contains($0.minutes) }) else { throw PlanError.invalidResponse }
        let lookup = Dictionary(uniqueKeysWithValues: originals.map { ($0.id.uuidString, $0) })
        let ordered = reply.tasks.compactMap { entry -> FocusTask? in
            guard var task = lookup[entry.id] else { return nil }
            if !task.explicitDuration { task.minutes = entry.minutes }
            return task
        }
        return TaskParser.enforceConstraints(ordered, input: input)
    }
}

public struct FocusClock: Codable, Equatable {
    public var remaining: TimeInterval = 0
    public var deadline: Date?
    public init() {}
    public func seconds(at now: Date = Date()) -> TimeInterval { max(0, deadline?.timeIntervalSince(now) ?? remaining) }
    public mutating func start(minutes: Int, now: Date = Date()) {
        remaining = Double(minutes * 60); deadline = now.addingTimeInterval(remaining)
    }
    public mutating func pause(now: Date = Date()) { remaining = seconds(at: now); deadline = nil }
    public mutating func resume(now: Date = Date()) { if remaining > 0 { deadline = now.addingTimeInterval(remaining) } }
    public mutating func add(minutes: Int, now: Date = Date()) {
        remaining = min(10_800, seconds(at: now) + Double(minutes * 60))
        if deadline != nil { deadline = now.addingTimeInterval(remaining) }
    }
}
