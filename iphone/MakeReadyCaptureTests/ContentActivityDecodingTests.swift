import XCTest
@testable import MakeReady

final class ContentActivityDecodingTests: XCTestCase {
    private enum Fixture {
        static let draftPayload = #"""
        {"version":{"id":"v1","lessonId":"l1","enrollmentId":null,"number":2,"status":"DRAFT",
                    "title":"Lesson","estimatedSeconds":90,"publishedAt":null},
         "activities":[
           {"id":"a1","lessonVersionId":"v1","activityKey":"k1","position":0,"kind":"text","title":"Text",
            "document":{"schemaVersion":1,"kind":"text","background":{"color":"#000000"},
                        "content":{"type":"canvas","objects":[]},"actions":[]},"estimatedSeconds":null},
           {"id":"a2","lessonVersionId":"v1","activityKey":"k2","position":1,"kind":"quiz","title":"Quiz",
            "document":{"schemaVersion":1,"kind":"quiz"},"estimatedSeconds":30}],
         "media":{"m1":{"url":"https://cdn.example/m1.jpg","width":800,"height":600,"kind":"image"},
                  "m2":{"url":"https://cdn.example/m2.mp4","kind":"video","playbackUrl":"https://cdn.example/m2.m3u8",
                        "posterUrl":"https://cdn.example/m2.jpg","durationSeconds":12.5,"uploaderName":"Sam"}}}
        """#
        static let publishedVersion = #"""
        {"id":"v9","lessonId":"l1","enrollmentId":"e1","number":3,"status":"PUBLISHED","title":null,
         "estimatedSeconds":null,"publishedAt":"2026-11-07T10:20:30.123Z"}
        """#
    }

    func testLessonVersionPayloadDecodes() throws {
        let p = try JSONDecoder.apiDecoder.decode(LessonVersionPayload.self, from: Data(Fixture.draftPayload.utf8))
        XCTAssertEqual(p.version.status, .draft)
        XCTAssertEqual(p.activities.map(\.activityKey), ["k1", "k2"])
        XCTAssertEqual(p.media["m1"]?.kind, "image")
    }

    func testMediaMapEntryCarriesVideoFields() throws {
        let p = try JSONDecoder.apiDecoder.decode(LessonVersionPayload.self, from: Data(Fixture.draftPayload.utf8))
        XCTAssertEqual(p.media["m2"]?.playbackUrl, "https://cdn.example/m2.m3u8")
        XCTAssertEqual(p.media["m2"]?.durationSeconds, 12.5)
        XCTAssertEqual(p.media["m2"]?.uploaderName, "Sam")
        XCTAssertNil(p.media["m1"]?.posterUrl)
    }

    func testAnUnknownKindDoesNotFailTheLesson() throws {
        let p = try JSONDecoder.apiDecoder.decode(LessonVersionPayload.self, from: Data(Fixture.draftPayload.utf8))
        guard case .fallback = p.activities[1].document.renderable else { return XCTFail("expected fallback") }
        guard case .canvas = p.activities[0].document.renderable else { return XCTFail("expected canvas") }
    }

    func testPublishedVersionWithFractionalSecondsDecodes() throws {
        let v = try JSONDecoder.apiDecoder.decode(LessonVersion.self, from: Data(Fixture.publishedVersion.utf8))
        XCTAssertEqual(v.status, .published)
        XCTAssertEqual(v.enrollmentId, "e1")
        XCTAssertNotNil(v.publishedAt)
    }
}
