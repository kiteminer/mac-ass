import XCTest
import AppKit
@testable import MacAss

final class StoreTests: XCTestCase {
    @MainActor private func fixture() -> (Store, NSPasteboard, URL, UserDefaults) {
        let id = UUID().uuidString
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        let pb = NSPasteboard(name: NSPasteboard.Name(id))
        let defaults = UserDefaults(suiteName: id)!
        return (Store(storageURL: url, pasteboard: pb, defaults: defaults, startTimer: false), pb, url, defaults)
    }
    @MainActor func testCompleteThenAddStartsNewTimer() {
        let (store, _, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(store.addManual("First task", minutes: 5))
        store.complete()
        XCTAssertNil(store.current)
        XCTAssertTrue(store.addManual("Second task", minutes: 15))
        XCTAssertEqual(store.current?.title, "Second task")
        XCTAssertGreaterThan(store.state.clock.seconds(), 899)
    }
    @MainActor func testClipboardEnableCapturesCurrentAndSubsequentText() {
        let (store, pb, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        store.clipboardEnabled = false
        pb.clearContents(); pb.setString("Current entry", forType: .string)
        store.clipboardEnabled = true
        XCTAssertEqual(store.history, ["Current entry"])
        pb.clearContents(); pb.setString("Next entry", forType: .string); store.tick()
        XCTAssertEqual(store.history, ["Next entry", "Current entry"])
        store.history.removeFirst(); store.tick()
        XCTAssertEqual(store.history, ["Current entry"])
    }
    @MainActor func testClipboardRejectsConcealedText() {
        let (store, pb, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        pb.clearContents(); pb.setString("Secret", forType: .string)
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        store.captureClipboard(force: true)
        XCTAssertTrue(store.history.isEmpty)
    }
    @MainActor func testSubtasksCanBeAddedToggledAndDeleted() {
        let (store, _, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertFalse(store.addSubtask("Orphan"))
        store.addManual("Work", minutes: 25)
        XCTAssertTrue(store.addSubtask("First step"))
        let id = store.current!.subtasks[0].id
        store.toggleSubtask(id); XCTAssertTrue(store.current!.subtasks[0].done)
        store.deleteSubtask(id); XCTAssertTrue(store.current!.subtasks.isEmpty)
    }
    @MainActor func testQueueStartAndDeleteWork() {
        let (store, _, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        store.addManual("One, Two, Three", minutes: 25)
        let second = store.state.tasks[1].id
        store.activateTask(second)
        XCTAssertEqual(store.current?.title, "Two")
        XCTAssertEqual(store.state.tasks[1].title, "One")
        store.deleteTask(store.state.tasks[2].id)
        XCTAssertEqual(store.state.tasks.count, 2)
    }
    @MainActor func testSwitchingQueuePreservesExactRemainingTime() {
        let (store, _, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        store.addManual("One, Two", minutes: 25)
        store.state.clock.pause(); store.state.clock.remaining = 123.4
        let first = store.current!.id
        store.activateTask(store.state.tasks[1].id)
        store.activateTask(first)
        XCTAssertEqual(store.state.clock.seconds(), 123.4, accuracy: 0.2)
    }
    @MainActor func testInvalidPlanDoesNotDismissOrLoseDraft() {
        let (store, _, url, _) = fixture(); defer { try? FileManager.default.removeItem(at: url) }
        store.expanded = true; store.draft = "My input"
        XCTAssertFalse(store.makePlan(" "))
        XCTAssertTrue(store.expanded)
        XCTAssertEqual(store.draft, "My input")
        XCTAssertFalse(store.busy)
    }
}
