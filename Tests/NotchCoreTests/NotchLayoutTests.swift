import XCTest
import CoreGraphics
@testable import NotchCore

final class NotchLayoutTests: XCTestCase {
    func testWindowRemainsAnchoredOnOffsetDisplay() {
        let screen = CGRect(x: -1512, y: 200, width: 1512, height: 982)
        let layout = NotchLayout(screen: screen, notchWidth: 180, notchHeight: 32)
        XCTAssertEqual(layout.windowFrame.maxY, screen.maxY)
        for expanded in [true, false] {
            let rect = layout.screenRect(expanded: expanded)
            XCTAssertEqual(rect.maxY, screen.maxY + 2)
            XCTAssertEqual(rect.midX, screen.midX)
            XCTAssertLessThanOrEqual(rect.height, 364)
            XCTAssertTrue(layout.windowFrame.insetBy(dx: -2, dy: -2).contains(rect))
        }
    }
    func testCollapsedStripNeverUsesMenuWings() {
        let layout = NotchLayout(screen: CGRect(x: 0, y: 0, width: 1728, height: 1117), notchWidth: 200, notchHeight: 38)
        XCTAssertEqual(layout.visibleSize(expanded: false).width, 200)
        XCTAssertEqual(layout.screenRect(expanded: false).minY, 1059)
    }
    func testPagesClampAfterDeletingLastItem() {
        XCTAssertEqual(PageBounds.page(3, count: 2, size: 3), 0)
        XCTAssertEqual(PageBounds.page(-1, count: 20, size: 3), 0)
        XCTAssertEqual(PageBounds.page(4, count: 0, size: 3), 0)
    }
}

final class PlanFormattingTests: XCTestCase {
    func testFencedPlanAndReasoningSuffixAreDecoded() throws {
        let json = #"{"tasks":[{"title":"Wash dishes","minutes":15,"subtasks":[]}]}"#
        for value in ["```json\n" + json + "\n```", "<think>Private reasoning</think>\n" + json] {
            XCTAssertEqual(try LocalPlanner.decodePlan(Data(value.utf8)).first?.title, "Wash dishes")
        }
    }
}
