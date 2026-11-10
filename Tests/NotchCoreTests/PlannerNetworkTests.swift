import Foundation
import XCTest
@testable import NotchCore

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var calls = 0
    static var started: (() -> Void)?
    static var suspendResponse = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            Self.calls += 1
            Self.started?()
            if Self.suspendResponse { return }
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class PlannerNetworkTests: XCTestCase {
    private func session() -> URLSession {
        StubProtocol.calls = 0
        StubProtocol.started = nil; StubProtocol.suspendResponse = false
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }
    func testServerFailureFallsBackWithoutRetry() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        StubProtocol.handler = { _ in (503, Data()) }
        let result = try await LocalPlanner.plan("clean up, go shopping", configuration: PlannerConfiguration(), session: session)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(result.tasks.count, 2)
        XCTAssertEqual(StubProtocol.calls, 1)
    }
    func testMalformedReplyHasOneRepairThenFallback() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        StubProtocol.handler = { _ in (200, Data(#"{"message":{"content":"I cannot return JSON"}}"#.utf8)) }
        let result = try await LocalPlanner.plan("clean up", configuration: PlannerConfiguration(), session: session)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(StubProtocol.calls, 2)
    }
    func testConnectionFailureFallsBack() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        StubProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let result = try await LocalPlanner.plan("resume 45 min", configuration: PlannerConfiguration(), session: session)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(result.tasks.first?.minutes, 45)
    }
    func testCancelledRequestDoesNotProduceFallbackTasks() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let started = expectation(description: "request started")
        StubProtocol.started = { started.fulfill() }; StubProtocol.suspendResponse = true
        let operation = Task {
            return try await LocalPlanner.plan("clean up", configuration: PlannerConfiguration(), session: session)
        }
        await fulfillment(of: [started], timeout: 3)
        operation.cancel()
        do { _ = try await operation.value; XCTFail("Cancellation should propagate") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(StubProtocol.calls, 1)
    }
    func testOversizedResponseIsRejected() async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        StubProtocol.handler = { _ in (200, Data(repeating: 65, count: 140_000)) }
        let result = try await LocalPlanner.plan("clean up", configuration: PlannerConfiguration(), session: session)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(StubProtocol.calls, 1)
    }
}
