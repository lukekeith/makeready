import XCTest
@testable import MakeReady

/// image-framing-editor D4/D10/D13: what an avatar tap does, read from AppState's member detail
/// (never the screen state); the menu rows per photo state; the viewer's URL.
@MainActor
final class MemberProfileAvatarTapTests: XCTestCase {
    private let r2 = "https://pub.r2.example/avatars/members/m1/1700000000.webp"
    private let google = "https://lh3.googleusercontent.com/a/ACg8oc=s96-c"

    private func detail(_ picture: String?, google: String? = nil, original: String? = nil) -> MemberDetail {
        MemberDetail(id: "m1", profilePicture: picture, googlePicture: google, profilePictureOriginalUrl: original)
    }

    /// D4: a tap before the detail loads does nothing.
    func testUnloadedMemberIsInert() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: nil), .none)
    }

    /// D4: no photo and no Google picture → the system picker.
    func testNoPhotoOpensThePicker() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(nil)), .picker)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("")), .picker)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("", google: "")), .picker)
    }

    /// D4/D15: an uploaded avatar (incl. the R2 copy made at Google linking) → Change · Edit · View.
    func testUploadedPhotoOpensTheFullMenu() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(r2)), .menu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(r2, google: google)), .menu)
    }

    /// D4: Google-only — no avatar, the avatar IS the Google picture, or it is hosted on googleusercontent.com.
    func testGoogleOnlyOpensChangeAndView() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(nil, google: google)), .googleMenu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(google, google: google)), .googleMenu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("https://lh5.googleusercontent.com/x/photo.jpg")), .googleMenu)
    }

    /// D4: the rows, in order, with existing glyphs; Google-only has no Edit; the picker states have none.
    func testMenuRowsPerState() {
        let full = MemberProfileContainer.avatarActions(.menu)
        XCTAssertEqual(full.map(\.label), ["Change image", "Edit image", "View image"])
        XCTAssertEqual(full.map(\.glyph), ["upload", "edit", "eye"])
        let googleOnly = MemberProfileContainer.avatarActions(.googleMenu)
        XCTAssertEqual(googleOnly.map(\.label), ["Change image", "View image"])
        XCTAssertEqual(googleOnly.map(\.glyph), ["upload", "eye"])
        XCTAssertTrue(MemberProfileContainer.avatarActions(.picker).isEmpty)
        XCTAssertTrue(MemberProfileContainer.avatarActions(.none).isEmpty)
        for row in full { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(full.map { MemberProfileContainer.AvatarChoice(label: $0.label) }, [.change, .edit, .view])
    }

    /// D13: the stored original first, else the avatar, else the Google picture.
    func testViewerURL() {
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(r2, google: google, original: "https://img/o.jpeg")), "https://img/o.jpeg")
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(r2, google: google, original: "")), r2)
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(nil, google: google)), google)
        XCTAssertNil(MemberProfileContainer.avatarViewerURL(detail: detail(nil)))
        XCTAssertNil(MemberProfileContainer.avatarViewerURL(detail: nil))
        XCTAssertEqual(MemberProfileContainer.viewerLabel, "Profile photo")
    }

    /// D10: the screen stores the closure; its default is a no-op.
    func testScreenAvatarHook() {
        var tapped = false
        let screen = MembersProfileScreen(state: .populated, showsHeader: false, onAvatarTap: { tapped = true })
        screen.onAvatarTap()
        XCTAssertTrue(tapped)
        MembersProfileScreen(state: .populated).onAvatarTap()
    }
}
