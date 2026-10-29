import XCTest
@testable import MakeReady

/// invite-member Fixes (agent walk round 1, E6): the 2.0 shell shows what `recordError(surface: true)`
/// surfaces — D10's send error, D12/D13's entry messages — and nothing for console-only errors.
@MainActor
final class UI2ErrorBannerHostTests: XCTestCase {
    func testASurfacedErrorIsShownWithItsFriendlyMessage() {
        let state = AppState()
        state.recordError(APIError.serverError("x"), context: "t", surface: true, friendlyMessage: "Rate limited")
        XCTAssertEqual(UI2ErrorBannerHost.message(for: state.activeSurfacedError), "Rate limited")
    }

    func testAConsoleOnlyErrorShowsNothing() {
        let state = AppState()
        state.recordError(APIError.serverError("x"), context: "t")
        XCTAssertNil(UI2ErrorBannerHost.message(for: state.activeSurfacedError))
    }

    func testItDismissesItselfAfterFourSeconds() {
        XCTAssertEqual(UI2ErrorBannerHost.autoDismiss, .seconds(4))
    }

    /// ui2-enrollment-create Fixes (agent walk round 2, E10): D6's `retry:` reaches the banner — Retry
    /// dismisses it, then re-runs the failed operation; an error without one shows no Retry.
    func testARetryableErrorOffersRetryThatDismissesThenReRuns() {
        let state = AppState()
        var order: [String] = []
        state.recordError(APIError.serverError("x"), context: "t", surface: true,
                          friendlyMessage: "Couldn't enroll", retry: { order.append("retry") })
        let action = UI2ErrorBannerHost.retryAction(for: state.activeSurfacedError) { order.append("dismiss") }
        XCTAssertNotNil(action)
        action?()
        XCTAssertEqual(order, ["dismiss", "retry"])
    }

    func testAnErrorWithoutRetryOffersNone() {
        let state = AppState()
        state.recordError(APIError.serverError("x"), context: "t", surface: true, friendlyMessage: "Rate limited")
        XCTAssertNil(UI2ErrorBannerHost.retryAction(for: state.activeSurfacedError) {})
    }
}
