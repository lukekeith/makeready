import XCTest
import UIKit
@testable import MakeReady

/// image-framing-editor D8/D12: saveAvatar posts the D8 multipart body through uploadWithStatus,
/// keeps the HTTP status on failure, and on success patches the member detail and every Members
/// list row of that member.
@MainActor
final class MemberSaveAvatarTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let endpoint = "/api/members/m1/avatar"
    private let framing = ImageFraming(scale: 2, rotation: 15, offsetX: 0.25, offsetY: -0.5, flipped: true, quarterTurns: 1)

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Tony", profilePicture: "https://img/old.webp"))
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [
            OrgMemberListItem(id: "m1", profilePicture: "https://img/old.webp"),
            OrgMemberListItem(id: "m2", profilePicture: "https://img/m2.webp")
        ])
        state.orgMembersByOrgId["org2"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m1")])
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func image(_ size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func actions() -> MemberActions { MemberActions(api: api, state: state) }

    private func stubSuccess() {
        api.stub("POST", endpoint, json: #"{"success":true,"data":{"url":"https://img/new.webp","originalUrl":"https://img/new-original.jpeg","framing":{"scale":2,"rotation":15,"offsetX":0.25,"offsetY":-0.5,"flipped":true,"quarterTurns":1}}}"#)
    }

    /// The parts of a multipart body by field name: each part's header block and payload.
    private func parts(_ body: Data, boundary: String) -> [String: (headers: String, payload: Data)] {
        var result: [String: (headers: String, payload: Data)] = [:]
        let delimiter = Data("--\(boundary)".utf8)
        let headerEnd = Data("\r\n\r\n".utf8)
        var cursor = body.startIndex
        while let start = body.range(of: delimiter, in: cursor..<body.endIndex),
              let next = body.range(of: delimiter, in: start.upperBound..<body.endIndex) {
            let chunk = Data(body[start.upperBound..<next.lowerBound])     // "\r\n<headers>\r\n\r\n<payload>\r\n"
            if let split = chunk.range(of: headerEnd), chunk.count >= split.upperBound + 2 {
                let headers = String(decoding: chunk.subdata(in: 0..<split.lowerBound), as: UTF8.self)
                let payload = chunk.subdata(in: split.upperBound..<(chunk.count - 2))
                if let name = headers.components(separatedBy: "name=\"").dropFirst().first?.components(separatedBy: "\"").first {
                    result[name] = (headers, payload)
                }
            }
            cursor = next.lowerBound
        }
        return result
    }

    /// D8: a new pick sends `framing` (a JSON string), `file` and `original`, each file a JPEG part.
    func testNewPickSendsFramingFileAndOriginal() async throws {
        stubSuccess()
        _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: image(CGSize(width: 80, height: 60)))
        let upload = try XCTUnwrap(api.lastUpload)
        XCTAssertEqual(upload.endpoint, endpoint)
        XCTAssertEqual(upload.timeout, 120)
        let p = parts(upload.body, boundary: upload.boundary)
        XCTAssertEqual(Set(p.keys), ["framing", "file", "original"])
        for name in ["file", "original"] {
            let part = try XCTUnwrap(p[name])
            XCTAssertTrue(part.headers.contains("Content-Type: image/jpeg"), name)
            XCTAssertTrue(part.headers.contains("filename=\""), name)
            XCTAssertEqual(Array(part.payload.prefix(2)), [0xFF, 0xD8], name)            // JPEG SOI
        }
        let framingPart = try XCTUnwrap(p["framing"])
        XCTAssertFalse(framingPart.headers.contains("Content-Type"))                      // a plain text field
        XCTAssertEqual(try JSONDecoder().decode(ImageFraming.self, from: framingPart.payload), framing)
    }

    /// D8: a re-edit of a stored original sends no `original`; the body closes with the final boundary.
    func testReEditSendsNoOriginal() async throws {
        stubSuccess()
        _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
        let upload = try XCTUnwrap(api.lastUpload)
        XCTAssertEqual(Set(parts(upload.body, boundary: upload.boundary).keys), ["framing", "file"])
        XCTAssertTrue(String(decoding: upload.body.suffix(64), as: UTF8.self).hasSuffix("--\(upload.boundary)--\r\n"))
    }

    /// D12: the returned fields land on the detail and on every Members-list row of the member.
    func testSuccessPatchesTheDetailAndEveryListRow() async throws {
        stubSuccess()
        let url = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: image())
        XCTAssertEqual(url, "https://img/new.webp")
        let d = try XCTUnwrap(state.memberDetails["m1"])
        XCTAssertEqual(d.profilePicture, "https://img/new.webp")
        XCTAssertEqual(d.profilePictureOriginalUrl, "https://img/new-original.jpeg")
        XCTAssertEqual(d.profilePictureFraming, framing)
        XCTAssertEqual(d.firstName, "Tony")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.members.map(\.profilePicture), ["https://img/new.webp", "https://img/m2.webp"])
        XCTAssertEqual(state.orgMembersByOrgId["org2"]?.members.first?.profilePicture, "https://img/new.webp")
    }

    /// D12: 403 and 404 keep their status for the model's outcome; nothing is written.
    func testForbiddenAndNotFoundKeepTheirStatusAndWriteNothing() async {
        for status in [403, 404] {
            api.errorFor = { _, _ in APIHTTPError(status: status, message: "no") }
            do {
                _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
                XCTFail("expected a throw for \(status)")
            } catch {
                XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: status, message: "no"))
            }
        }
        XCTAssertEqual(state.memberDetails["m1"]?.profilePicture, "https://img/old.webp")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.members.first?.profilePicture, "https://img/old.webp")
    }

    /// ui2-shell D27: a 401 surfaces as the error the sign-out policy reads.
    func testUnauthorizedIsTheSignOutError() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        do {
            _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: error))
        }
    }

    /// A 2xx without `success`/`data.url` is a failure, and writes nothing.
    func testUnsuccessfulBodyThrowsAndWritesNothing() async {
        api.stub("POST", endpoint, json: #"{"success":false,"error":"nope"}"#)
        do {
            _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, APIError.serverError("nope").localizedDescription)
        }
        XCTAssertEqual(state.memberDetails["m1"]?.profilePicture, "https://img/old.webp")
    }

    /// D8: the avatar route's 413 keeps its status through the shared mapping `uploadWithStatus` uses.
    func testStatusMappingKeepsA413() {
        let data = Data(#"{"error":"File too large"}"#.utf8)
        XCTAssertEqual(APIClient.statusError(status: 413, data: data) as? APIHTTPError, APIHTTPError(status: 413, message: "File too large"))
        XCTAssertNil(APIClient.statusError(status: 200, data: data))
    }
}
