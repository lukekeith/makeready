import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D10/D13: saveCover posts the rendered cover + framing (+ the original on a new
/// pick) through requestWithStatus and patches the returned fields into AppState.
@MainActor
final class GroupSaveCoverTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let endpoint = "/api/groups/g1/cover-image"
    private let framing = CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2)

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        state.groups.upsert(UserGroup(id: "g1", code: "ABC123", name: "Prayer Team", coverImageUrl: "https://img/old.jpeg",
                                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u1",
                                      createdAt: Date(), updatedAt: Date()))
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func image(_ size: CGSize = CGSize(width: 40, height: 20)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func stubSuccess() {
        api.stub("POST", endpoint, json: #"{"success":true,"coverImageUrl":"https://img/new.jpeg","coverOriginalUrl":"https://img/new-original.jpeg","coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2}}"#)
    }

    func testNewPickSendsRenderedFramingAndOriginal() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: image())
        let body = try XCTUnwrap(api.calls.last?.body)
        XCTAssertFalse((body["imageData"] as? String ?? "").isEmpty)
        XCTAssertEqual(body["contentType"] as? String, "image/jpeg")
        XCTAssertEqual((body["framing"] as? [String: Any])?["scale"] as? Double, 2)
        XCTAssertFalse((body["originalData"] as? String ?? "").isEmpty)
    }

    func testReEditSendsNoOriginal() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
        XCTAssertNil(api.calls.last?.body?["originalData"])
    }

    func testSuccessPatchesTheThreeFieldsIntoAppState() async throws {
        stubSuccess()
        let result = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: image())
        XCTAssertEqual(result, CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: "https://img/new-original.jpeg", coverFraming: framing))
        let group = try XCTUnwrap(state.groups["g1"])
        XCTAssertEqual(group.coverImageUrl, "https://img/new.jpeg")
        XCTAssertEqual(group.coverOriginalUrl, "https://img/new-original.jpeg")
        XCTAssertEqual(group.coverFraming, framing)
    }

    /// F6: the status survives — a 404 is APIHTTPError(404), not a folded serverError.
    func testNotFoundKeepsItsStatus() async {
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        do {
            _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: 404, message: "Group not found"))
        }
        XCTAssertEqual(state.groups["g1"]?.coverImageUrl, "https://img/old.jpeg")
    }

    func testRenderedIsJPEGBase64() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
        let b64 = try XCTUnwrap(api.calls.last?.body?["imageData"] as? String)
        let data = try XCTUnwrap(Data(base64Encoded: b64))
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])   // JPEG SOI
    }
}
