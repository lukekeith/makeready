import XCTest
import UIKit
@testable import MakeReady

/// media-library D13: the Media page's uploads run in AppState's queue; a photo lands in the library at
/// once, with its org; one failure surfaces and the rest still land; a video is not inserted locally.
@MainActor
final class MediaUploadQueueTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let endpoint = "/api/organizations/o2/media/upload"

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        state.organizationId = "o1"
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func image() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    func testPhotosLandInTheChosenOrgWithTheUploader() async {
        api.stub("POST", endpoint, json: #"{"success":true,"data":{"id":"p1","url":"https://img/p1.jpeg","thumbnailUrl":"https://img/p1-thumb.jpeg"}}"#)
        let queue = MediaUploadQueue()
        queue.enqueue([.photo(image(), data: nil)], orgId: "o2", uploader: MediaUploader(id: "u1", name: "Ann"),
                      state: state, actions: MediaActions(api: api, state: state))
        XCTAssertEqual(queue.pending, 1)
        await queue.drain()
        XCTAssertEqual(queue.pending, 0)
        let item = state.mediaLibrary.all.first { $0.id == "p1" }
        XCTAssertEqual(item?.organizationId, "o2")
        XCTAssertEqual(item?.uploader?.name, "Ann")
        XCTAssertEqual(item?.isMakeReady, false)
        XCTAssertEqual(api.calls.last?.endpoint, endpoint)
        XCTAssertEqual(api.calls.last?.body?["title"] as? String, "Photo")
    }

    func testOneFailureSurfacesAndTheRestStillLand() async {
        api.stub("POST", endpoint, json: #"{"success":true,"data":{"id":"p2","url":"https://img/p2.jpeg","thumbnailUrl":null}}"#)
        var n = 0
        api.errorFor = { _, _ in n += 1; return n == 1 ? APIError.serverError("boom") : nil }
        let queue = MediaUploadQueue()
        queue.enqueue([.photo(image(), data: nil), .photo(image(), data: nil)], orgId: "o2", uploader: nil,
                      state: state, actions: MediaActions(api: api, state: state))
        await queue.drain()
        XCTAssertEqual(state.mediaLibrary.all.map(\.id), ["p2"])
        XCTAssertEqual(queue.pending, 0)
    }

    func testAVideoStartsThroughMediaUploadAndIsNotInsertedLocally() async {
        api.stub("POST", endpoint, json: #"{"success":true,"data":{"media":{"id":"v1"},"uploadUrl":"https://upload.test/v1","videoId":"vid1"}}"#)
        let queue = MediaUploadQueue()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("queue-test.mov")
        try? Data([0, 1, 2]).write(to: file)
        queue.enqueue([.video(file)], orgId: "o2", uploader: nil, state: state, actions: MediaActions(api: api, state: state))
        await queue.drain()
        XCTAssertEqual(api.calls.first?.body?["type"] as? String, "video")
        XCTAssertTrue(state.mediaLibrary.all.isEmpty)
    }

    func testTitleCarriesTheCaptureDay() {
        XCTAssertEqual(MediaUploadQueue.title("Photo", takenAt: nil), "Photo")
        XCTAssertTrue(MediaUploadQueue.title("Photo", takenAt: "2025-06-14T09:30:00-05:00").hasPrefix("Photo · "))
    }
}
