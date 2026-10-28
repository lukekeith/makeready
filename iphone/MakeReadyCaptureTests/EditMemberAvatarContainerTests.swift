import XCTest
import UIKit
@testable import MakeReady

/// image-framing-editor D3/D5/D7/D9/D12: the Edit photo page's geometry, opening rule and routing,
/// without the view.
@MainActor
final class EditMemberAvatarContainerTests: XCTestCase {
    /// D12: success, 403 and 404 all pop back to the profile; 401 signs out; anything else is the banner.
    func testOutcomeRoutes() {
        XCTAssertEqual(EditMemberAvatarContainer.route(.saved), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.forbidden), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.gone), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.unauthorized), .signOut)
        XCTAssertEqual(EditMemberAvatarContainer.route(.failed("x")), .banner)
        XCTAssertEqual(EditMemberAvatarContainer.route(.ignored), .stay)
    }

    func testDestinationIsHashableWithAPick() {
        let img = UIImage()
        let a = UI2Destination.editMemberAvatar(memberId: "m1", source: .newPick(img))
        XCTAssertEqual(a, UI2Destination.editMemberAvatar(memberId: "m1", source: .newPick(img)))
        XCTAssertNotEqual(a, UI2Destination.editMemberAvatar(memberId: "m1", source: .stored))
        XCTAssertNotEqual(UI2Destination.editMemberAvatar(memberId: "m1", source: .stored),
                          UI2Destination.editGroupCover(groupId: "m1", source: .stored))
    }

    /// D5: the stored original at its framing; no original → the avatar itself at identity (and the
    /// first save stores it as the original); no avatar → nil.
    func testOpening() {
        let f = ImageFraming(scale: 2, rotation: 10, offsetX: 0.1, offsetY: 0)
        let stored = MemberDetail(id: "m1", profilePicture: "https://img/a.webp",
                                  profilePictureOriginalUrl: "https://img/o.jpeg", profilePictureFraming: f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.url, "https://img/o.jpeg")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.framing, f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.hasOriginal, true)

        let noFraming = MemberDetail(id: "m1", profilePicture: "https://img/a.webp", profilePictureOriginalUrl: "https://img/o.jpeg")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: noFraming)?.framing, .identity)

        let legacy = MemberDetail(id: "m1", profilePicture: "https://img/a.webp", profilePictureOriginalUrl: "", profilePictureFraming: f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.url, "https://img/a.webp")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.framing, .identity)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.hasOriginal, false)

        XCTAssertNil(EditMemberAvatarContainer.opening(detail: MemberDetail(id: "m1", profilePicture: "")))
        XCTAssertNil(EditMemberAvatarContainer.opening(detail: MemberDetail(id: "m1")))
    }

    /// D3/D7/D9: square frame, 512×512 render, "Edit photo"; the group cover keeps 16:9 and "Edit cover".
    func testGeometryAndText() {
        XCTAssertEqual(EditMemberAvatarContainer.frameAspect, 1)
        XCTAssertEqual(EditMemberAvatarContainer.renderSize, CGSize(width: 512, height: 512))
        XCTAssertEqual(EditMemberAvatarContainer.title, "Edit photo")
        XCTAssertEqual(EditMemberAvatarContainer.saveFailedMessage, "Couldn't save the photo")
        XCTAssertEqual(EditGroupCoverContainer.title, "Edit cover")
        XCTAssertEqual(EditGroupCoverContainer.frameAspect, 16.0 / 9.0, accuracy: 1e-12)
    }
}
