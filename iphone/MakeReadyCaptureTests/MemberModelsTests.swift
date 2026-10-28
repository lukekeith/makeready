import XCTest
@testable import MakeReady

/// ui2-members-browse T9 / F7: SPEC §Contract's member payloads decode through the app's API
/// decoder; every date stays the server's String (Prisma `.SSSZ`), every missing key defaults.
final class MemberModelsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(type, from: Data(json.utf8))
    }

    func testDirectoryDecodesTheListShapeWithViewerScope() throws {
        let json = #"{"success":true,"data":[{"id":"m1","firstName":"Barry","lastName":"Allen","profilePicture":null,"googlePicture":"https://lh3.example/b.jpg","joinedAt":"2026-10-25T14:03:22.123Z","groupCount":2},{"id":"m2","firstName":"Clark","lastName":null,"joinedAt":"2026-07-25T00:00:00Z","groupCount":0}],"count":2,"viewerScope":{"all":false,"groupIds":["g1","g2"]}}"#
        let r = try decode(OrgMembersResponse.self, json)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.data.map(\.id), ["m1", "m2"])
        XCTAssertEqual(r.data[0].joinedAt, "2026-10-25T14:03:22.123Z")          // .SSSZ kept verbatim
        XCTAssertNil(r.data[0].profilePicture)
        XCTAssertEqual(r.data[0].googlePicture, "https://lh3.example/b.jpg")
        XCTAssertEqual(r.data[0].groupCount, 2)
        XCTAssertNil(r.data[1].lastName)
        XCTAssertEqual(r.viewerScope, ViewerScope(all: false, groupIds: ["g1", "g2"]))
    }

    func testDirectoryWithoutTheNewKeysDefaults() throws {
        let r = try decode(OrgMembersResponse.self, #"{"success":true,"data":[{"id":"m1"}]}"#)
        XCTAssertNil(r.viewerScope)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.data.first?.joinedAt, "")
        XCTAssertEqual(r.data.first?.groupCount, 0)
        XCTAssertNil(r.data.first?.firstName)
    }

    func testMemberDetailDecodesTheScopedPayload() throws {
        let json = #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890","phoneVerified":true,"smsConsent":true,"firstName":"Tony","lastName":"Stark","email":null,"googleEmail":"tony@gmail.example","gender":"male","birthday":"1974-06-25T00:00:00.000Z","profilePicture":null,"googlePicture":"https://lh3.example/t.jpg","isActive":true,"userId":"u1","address":"10880 Malibu Point\nMalibu, CA 90265","emergencyContactName":"Pepper Potts","emergencyContactPhone":"+11234567891","isGroupLeader":true,"createdAt":"2026-01-02T03:04:05.678Z","organizations":[{"id":"mo1","memberId":"m1","organizationId":"org1","joinedAt":"2026-07-05T14:03:22.123Z","createdAt":"2026-07-05T14:03:22.123Z","organization":{"id":"org1","name":"MakeReady","ownerId":"u9"}}]}}"#
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, json).data)
        XCTAssertEqual(d.id, "m1")
        XCTAssertEqual(d.phoneNumber, "+11234567890")
        XCTAssertTrue(d.phoneVerified)
        XCTAssertEqual(d.firstName, "Tony")
        XCTAssertNil(d.email)
        XCTAssertEqual(d.googleEmail, "tony@gmail.example")
        XCTAssertEqual(d.gender, "male")
        XCTAssertEqual(d.birthday, "1974-06-25T00:00:00.000Z")
        XCTAssertEqual(d.googlePicture, "https://lh3.example/t.jpg")
        XCTAssertEqual(d.address, "10880 Malibu Point\nMalibu, CA 90265")
        XCTAssertEqual(d.emergencyContactName, "Pepper Potts")
        XCTAssertEqual(d.emergencyContactPhone, "+11234567891")
        XCTAssertTrue(d.isGroupLeader)
        XCTAssertEqual(d.organizations, [MemberDetailOrganization(
            organizationId: "org1", joinedAt: "2026-07-05T14:03:22.123Z",
            organization: MemberOrganizationRef(id: "org1", name: "MakeReady"))])
    }

    func testMemberDetailFromAServerWithoutTheNewColumnsDefaults() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890"}}"#).data)
        XCTAssertNil(d.address)
        XCTAssertNil(d.emergencyContactName)
        XCTAssertNil(d.emergencyContactPhone)
        XCTAssertFalse(d.isGroupLeader)
        XCTAssertFalse(d.phoneVerified)
        XCTAssertEqual(d.organizations, [])
    }

    func testMemberGroupsDecodeTheGroupPayload() throws {
        let json = #"{"success":true,"data":[{"id":"g1","code":"ABC123","name":"Young professionals","coverImageUrl":"https://cdn.example/g1.jpg","creatorId":"u2","organizationId":"org1","isActive":true,"createdAt":"2025-01-01T00:00:00.000Z","memberCount":9,"joinedAt":"2025-07-03T16:00:00.000Z","creator":{"id":"u2","name":"Luke Keith","email":"luke@example.org","picture":null},"_count":{"members":9}}],"count":1}"#
        let r = try decode(MemberGroupsResponse.self, json)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.data, [MemberGroupItem(
            id: "g1", name: "Young professionals", coverImageUrl: "https://cdn.example/g1.jpg",
            organizationId: "org1", memberCount: 9, joinedAt: "2025-07-03T16:00:00.000Z",
            creator: MemberGroupCreator(id: "u2", name: "Luke Keith"))])
    }

    func testEngagementDecodesTotalCountAndWholeHours() throws {
        let json = #"{"programs":[{"enrollmentId":"e1","programId":"p1","title":"Daily Inspiration","coverImageUrl":"https://cdn.example/p1.jpg","completedCount":12,"totalCount":30,"hours":15,"percent":68},{"enrollmentId":"e2","programId":"p2","title":"Romans in 30 days","coverImageUrl":null,"completedCount":31,"totalCount":31,"hours":92,"percent":100}]}"#
        let e = try decode(MemberEngagement.self, json)
        XCTAssertEqual(e.programs.count, 2)
        XCTAssertEqual(e.programs[0], MemberEngagementProgram(
            enrollmentId: "e1", programId: "p1", title: "Daily Inspiration",
            coverImageUrl: "https://cdn.example/p1.jpg", completedCount: 12, totalCount: 30, hours: 15, percent: 68))
        XCTAssertNil(e.programs[1].coverImageUrl)
        XCTAssertEqual(e.programs[1].totalCount, 31)
    }

    func testEngagementMissingKeysDefault() throws {
        let e = try decode(MemberEngagement.self, #"{"programs":[{"title":"Romans"}]}"#)
        XCTAssertEqual(e.programs, [MemberEngagementProgram(title: "Romans")])
        XCTAssertEqual(try decode(MemberEngagement.self, "{}").programs, [])
    }

    /// SC7: `lastActivityAt` is additive on a payload Home already decodes.
    func testHomeDayCarriesLastActivityAt() throws {
        let json = #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0],"lastActivityAt":"2026-10-24T13:20:00.000Z"},{"day":"2026-10-25","sessionSeconds":0,"blocks":[0,0,0,0,0,0,0,0,0,0,0,0],"lastActivityAt":null},{"day":"2026-10-26","sessionSeconds":0}]}"#
        let days = try decode(HomeDaysResponse.self, json).days
        XCTAssertEqual(days[0].lastActivityAt, "2026-10-24T13:20:00.000Z")
        XCTAssertNil(days[1].lastActivityAt)
        XCTAssertNil(days[2].lastActivityAt)
        XCTAssertEqual(days[2].blocks, [])
        XCTAssertNil(HomeDay(day: "2026-10-24", sessionSeconds: 60, blocks: [60]).lastActivityAt)   // old init still compiles
    }

    /// D18: the shape `/my/organization` already decodes, as a list.
    func testMyOrganizationsDecodesTheList() throws {
        let json = #"{"success":true,"data":[{"id":"org2","name":"Grace Church","ownerId":"u9","createdAt":"2024-01-15T10:30:00.000Z","updatedAt":"2024-01-15T10:30:00.000Z"},{"id":"org3","name":"Second Org"}]}"#
        let r = try decode(MyOrganizationsResponse.self, json)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.data.map(\.id), ["org2", "org3"])
        XCTAssertEqual(try decode(MyOrganizationsResponse.self, #"{"success":true}"#).data, [])
    }

    // MARK: - image-framing-editor SC1/SC2 (§iphone State)

    func testMemberDetailDecodesTheAvatarOriginalAndFraming() throws {
        let json = #"{"success":true,"data":{"id":"m1","profilePicture":"https://img/a.webp","profilePictureOriginalUrl":"https://img/o.jpeg","profilePictureFraming":{"scale":2,"rotation":15,"offsetX":0.25,"offsetY":-0.5,"flipped":true,"quarterTurns":1}}}"#
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, json).data)
        XCTAssertEqual(d.profilePictureOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(d.profilePictureFraming, ImageFraming(scale: 2, rotation: 15, offsetX: 0.25, offsetY: -0.5, flipped: true, quarterTurns: 1))
    }

    /// A server without SC1/SC2 (and the in-memory store written before them) still decodes.
    func testMemberDetailWithoutTheAvatarFieldsDecodesAsNil() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","profilePicture":null}}"#).data)
        XCTAssertNil(d.profilePictureOriginalUrl)
        XCTAssertNil(d.profilePictureFraming)
        let nulls = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","profilePictureOriginalUrl":null,"profilePictureFraming":null}}"#).data)
        XCTAssertNil(nulls.profilePictureFraming)
    }

    /// A bad stored framing never fails the member decode.
    func testBadAvatarFramingDecodesAsNilAndKeepsTheMember() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","firstName":"Tony","profilePictureFraming":{"scale":"big"}}}"#).data)
        XCTAssertNil(d.profilePictureFraming)
        XCTAssertEqual(d.firstName, "Tony")
    }

    /// The memory-only store round-trips the two fields through Codable.
    func testMemberDetailRoundTripsTheAvatarFields() throws {
        let f = ImageFraming(scale: 3, rotation: -10, offsetX: 0, offsetY: 0.5)
        let d = MemberDetail(id: "m1", profilePictureOriginalUrl: "https://img/o.jpeg", profilePictureFraming: f)
        let again = try JSONDecoder.apiDecoder.decode(MemberDetail.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(again.profilePictureOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(again.profilePictureFraming, f)
    }
}
