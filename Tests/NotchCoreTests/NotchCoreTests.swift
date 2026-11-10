import XCTest
@testable import NotchCore

final class NotchCoreTests: XCTestCase {
    func testNestedTasksAndHomeFirst() throws {
        let tasks = try TaskParser.parse("go shopping, update resume (tools, workplace), clean up, home first")
        XCTAssertEqual(tasks.count, 3)
        XCTAssertEqual(tasks[0].subtasks.map(\.title), ["tools", "workplace"])
        XCTAssertEqual(tasks.last?.title, "go shopping")
    }
    func testInputBounds() {
        XCTAssertThrowsError(try TaskParser.parse("  "))
        XCTAssertThrowsError(try TaskParser.parse(String(repeating: "a", count: 4001)))
        XCTAssertThrowsError(try TaskParser.parse(Array(repeating: "task", count: 21).joined(separator: ",")))
    }
    func testReplyCannotOmitInventOrDuplicateTasks() throws {
        let tasks = try TaskParser.parse("clean up, resume")
        for ids in [[tasks[0].id.uuidString], [tasks[0].id.uuidString, tasks[0].id.uuidString], [UUID().uuidString, tasks[1].id.uuidString]] {
            let data = try JSONSerialization.data(withJSONObject: ["tasks": ids.map { ["id": $0, "minutes": 25] as [String: Any] }])
            XCTAssertThrowsError(try PlanValidator.apply(data, to: tasks, input: ""))
        }
    }
    func testExplicitMinutesAndConstraintSurviveModel() throws {
        let input = "clean up 20 min, go shopping, home first"
        let tasks = try TaskParser.parse(input)
        let data = try JSONSerialization.data(withJSONObject: ["tasks": tasks.reversed().map { ["id": $0.id.uuidString, "minutes": 60] as [String: Any] }])
        let result = try PlanValidator.apply(data, to: tasks, input: input)
        XCTAssertEqual(result.first?.minutes, 20)
        XCTAssertEqual(result.last?.location, "outside")
        XCTAssertEqual(Set(result.map(\.title)), Set(tasks.map(\.title)))
    }
    func testMalformedAndOutOfBoundsReplies() throws {
        let tasks = try TaskParser.parse("task")
        for minutes in [-1, 0, 181, 100000] {
            let data = Data("{\"tasks\":[{\"id\":\"\(tasks[0].id)\",\"minutes\":\(minutes)}]}".utf8)
            XCTAssertThrowsError(try PlanValidator.apply(data, to: tasks, input: ""))
        }
        XCTAssertThrowsError(try PlanValidator.apply(Data("<think>hello</think>".utf8), to: tasks, input: ""))
    }
    func testOnlyLoopbackOriginsAllowed() throws {
        var config = PlannerConfiguration()
        for address in ["https://example.com", "http://localhost.evil.test", "file:///tmp/test", "http://user@localhost:8080", "http://localhost:8080/v1", "http://localhost:8080?x=1"] {
            config.endpoint = address
            XCTAssertThrowsError(try LocalPlanner.endpoint(config))
        }
        config.endpoint = "http://127.0.0.1:8080"; config.openAICompatible = true
        XCTAssertEqual(try LocalPlanner.endpoint(config).path, "/v1/chat/completions")
    }
    func testClockPauseExtendSleepAndRestore() throws {
        let now = Date(timeIntervalSince1970: 1000)
        var clock = FocusClock(); clock.start(minutes: 25, now: now)
        XCTAssertEqual(clock.seconds(at: now.addingTimeInterval(60)), 1440)
        clock.pause(now: now.addingTimeInterval(60))
        XCTAssertEqual(clock.seconds(at: now.addingTimeInterval(500)), 1440)
        clock.add(minutes: 5, now: now.addingTimeInterval(500))
        XCTAssertNil(clock.deadline)
        clock.resume(now: now.addingTimeInterval(500))
        let restored = try JSONDecoder().decode(FocusClock.self, from: JSONEncoder().encode(clock))
        XCTAssertEqual(restored.seconds(at: now.addingTimeInterval(510)), 1730)
        XCTAssertEqual(restored.seconds(at: now.addingTimeInterval(10_000)), 0)
    }
}
