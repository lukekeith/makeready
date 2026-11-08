import XCTest
@testable import MakeReady

/// text-activity D26: a canvas-kind rail slide is the document drawn with C-092 in viewer mode.
@MainActor
final class ActivityThumbnailTests: XCTestCase {
    private func summary(_ id: String, kind: String = "text", text: String = "Hello") -> ActivitySummary {
        let json = ##"{"id":"\##(id)","activityKey":"k","position":0,"kind":"\##(kind)","title":"T","document":{"schemaVersion":1,"kind":"\##(kind)","background":{"color":"#0E4A4D"},"content":{"type":"canvas","verticalAnchor":"center","objects":[{"id":"o1","text":"\##(text)","font":"serif","weight":700,"size":26,"color":"#FFFFFF","alignment":"center","transform":{"x":220,"y":478,"width":392,"scale":1,"rotation":0}}]},"actions":[]}}"##
        return try! JSONDecoder.apiDecoder.decode(ActivitySummary.self, from: Data(json.utf8))
    }

    func testCanvasKindsGetAKeyAndOtherKindsDoNot() {
        XCTAssertTrue(ActivityThumbnail.key(for: summary("a")).hasPrefix("activity-thumbnail://"))
        XCTAssertFalse(ActivityThumbnail.key(for: summary("a", kind: "bible")).isEmpty)
        let video = try! JSONDecoder.apiDecoder.decode(ActivitySummary.self, from: Data(
            ##"{"id":"v","activityKey":"k","position":0,"kind":"video","title":"V","document":{"schemaVersion":1,"kind":"video","content":{"videoId":"x"}}}"##.utf8))
        XCTAssertEqual(ActivityThumbnail.key(for: video), "")
    }

    func testTheKeyChangesWithTheDocument() {
        XCTAssertEqual(ActivityThumbnail.key(for: summary("a")), ActivityThumbnail.key(for: summary("a")))
        XCTAssertNotEqual(ActivityThumbnail.key(for: summary("a")), ActivityThumbnail.key(for: summary("a", text: "Changed")))
    }

    func testTheMapperPutsTheRenderedKeyInTheRailForCanvasKinds() {
        let activity = summary("a")
        XCTAssertEqual(StudyProgramHomeMapper.slideImage(activity, media: [:]), ActivityThumbnail.key(for: activity))
    }

    func testSeedRendersTheSlideIntoTheCacheOnce() async throws {
        let activity = summary("seeded-\(UUID().uuidString)")
        let url = try XCTUnwrap(URL(string: ActivityThumbnail.key(for: activity)))
        XCTAssertNil(Ui2ImageCache.shared.image(for: url))
        let first = await ActivityThumbnail.seed([activity], media: [:])
        XCTAssertTrue(first)
        let image = try XCTUnwrap(Ui2ImageCache.shared.image(for: url))
        XCTAssertEqual(image.size.width, 33, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 44, accuracy: 0.5)
        let second = await ActivityThumbnail.seed([activity], media: [:])
        XCTAssertFalse(second)
    }
}
