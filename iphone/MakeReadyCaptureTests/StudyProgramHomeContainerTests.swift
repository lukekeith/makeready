import SwiftUI
import UIKit
import XCTest
@testable import MakeReady

/// ui2-programs D5/D7/D10: the program page's pure decisions.
@MainActor
final class StudyProgramHomeContainerTests: XCTestCase {
    func testLoadFailureClassification() {
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIHTTPError(status: 404, message: nil)), .gone)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: CancellationError()), .cancelled)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIHTTPError(status: 500, message: nil)), .failed)
    }

    /// program-lesson-add-activity D10/D17: the picker's strip — activities by order, then the placeholder, active.
    func testActivityNewStripListsActivitiesThenThePlaceholder() {
        let lesson = Lesson(id: "l1", dayNumber: 1, title: "A",
                            activities: [StudyActivity(id: "a2", type: .read, orderNumber: 2, title: "Second"),
                                         StudyActivity(id: "a1", type: .video, orderNumber: 1, title: "First")])
        let s = ActivityNewMapper.state(lesson: lesson)
        XCTAssertEqual(s.slideIDs, ["a1", "a2", "placeholder"])
        XCTAssertEqual(s.slideLabels, ["First", "Second", "New activity"])
        XCTAssertEqual(s.activeID, "placeholder")
        XCTAssertEqual(s.pendingType, "")
        XCTAssertFalse(s.createFailed)
    }

    /// D17: a lesson missing from AppState shows the placeholder alone.
    func testActivityNewWithoutTheLessonShowsThePlaceholderAlone() {
        let s = ActivityNewMapper.state(lesson: nil)
        XCTAssertEqual(s.slideIDs, ["placeholder"])
        XCTAssertEqual(s.slideLabels, ["New activity"])
    }

    func testSettingsRowsOpenTheirEditPageOnceLoaded() {
        let program = StudyProgram(id: "p1", name: "Walk")
        XCTAssertEqual(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Age", program: program),
                       .editProgramField(programId: "p1", field: .ageRange))
        XCTAssertNil(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Lessons", program: program))
        XCTAssertNil(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Age", program: nil))
    }

    func testImageURLsSkipEmpties() {
        var s = StudyProgramHomeMapper.state(.init(name: "", program: nil, lessons: [], enrollments: [], failed: false, activeDay: 1),
                                             timeZone: .current)
        s.coverURL = "https://c"
        s.lessonSlideImages = [["https://s", ""]]
        s.enrollmentPhotoURLs = ["", "https://g"]
        XCTAssertEqual(StudyProgramHomeContainer.imageURLs(s), ["https://c", "https://s"])   // rows load list copies
    }

    /// D12: the closures d2m delivered are the names the container calls.
    func testProgramPageTakesBothLessonClosures() {
        let state = StudyProgramHomeMapper.state(.init(name: "", program: nil, lessons: [], enrollments: [], failed: false, activeDay: 1),
                                                 timeZone: .current)
        _ = StudyProgramHomeScreen(state: state, onAddActivity: { _ in }, onOpenLessonMenu: { _ in })
    }

    /// D13/F5: the 775pt minimum is gone, so the picker fits a proposed 700pt.
    func testActivityNewFitsAPhone() {
        let host = UIHostingController(rootView: ActivityNewScreen(state: .populated))
        XCTAssertLessThanOrEqual(host.sizeThatFits(in: CGSize(width: 390, height: 700)).height, 700)
    }

    /// program-lesson-add-activity D4/D16: the chevron menu's rows, in order.
    func testLessonMenuRowsInOrderWithGlyphsAndTones() {
        let rows = StudyProgramHomeContainer.lessonMenuRows(lessonCount: 2)
        XCTAssertEqual(rows.map(\.label), ["Add activity", "Delete lesson"])
        XCTAssertEqual(rows.map(\.glyph), ["add-large-carbon", "trash-2"])
        // A glyph the library lacks draws the dashed error stub, so every row must resolve.
        for row in rows { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(rows.map(\.tone), [.standard, .destructive])
    }

    /// D5: the only lesson can't be deleted.
    func testLessonMenuTitleNamesTheDayAndTitle() {
        XCTAssertEqual(StudyProgramHomeContainer.lessonMenuTitle(dayNumber: 15, title: "It is evident"), "Day 15 · It is evident")
    }

    func testLessonMenuTitleIsOnlyTheDayWithNoTitle() {
        XCTAssertEqual(StudyProgramHomeContainer.lessonMenuTitle(dayNumber: 15, title: nil), "Day 15")
        XCTAssertEqual(StudyProgramHomeContainer.lessonMenuTitle(dayNumber: 15, title: ""), "Day 15")
        XCTAssertEqual(StudyProgramHomeContainer.lessonMenuTitle(dayNumber: 15, title: "   "), "Day 15")
    }

    func testLessonMenuOmitsDeleteForTheOnlyLesson() {
        XCTAssertEqual(StudyProgramHomeContainer.lessonMenuRows(lessonCount: 1).map(\.label), ["Add activity"])
    }

    /// D8/D9: the confirmation copy and the failure banner.
    func testDeleteConfirmationStrings() {
        XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmTitle, "Delete lesson?")
        XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmMessage, "This lesson and its activities will be permanently deleted.")
        XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmAction.label, "Delete lesson")
        XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmAction.tone, .destructive)
        XCTAssertEqual(StudyProgramHomeContainer.deleteLessonFailedMessage, "Couldn't delete the lesson")
    }

    /// D15/D19: cancelled is silent, 401 signs out, everything else (404 included) is the banner.
    func testDeleteFailureRouting() {
        XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: CancellationError()), .silent)
        XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIHTTPError(status: 404, message: nil)), .banner)
        XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIError.serverError("nope")), .banner)
    }

    /// D16: the index the screen sends maps to the right lesson by day order.
    func testLessonIDFollowsDayOrder() {
        let lessons = [Lesson(id: "l2", dayNumber: 2, title: ""), Lesson(id: "l1", dayNumber: 1, title: "")]
        XCTAssertEqual(StudyProgramHomeContainer.lessonID(at: 0, in: lessons), "l1")
        XCTAssertEqual(StudyProgramHomeContainer.lessonID(at: 1, in: lessons), "l2")
        XCTAssertNil(StudyProgramHomeContainer.lessonID(at: 2, in: lessons))
    }
}

/// program-day-rail-sticky: a day chip's scroll must leave the whole lesson visible, its title row below
/// the pinned rail. Measured in the real scroll view, because the landing is SwiftUI's.
@MainActor
final class StudyProgramHomeLandingTests: XCTestCase {
    private final class ProxyBox { var proxy: ScrollViewProxy? }

    func testASelectedDayLandsItsTitleRowBelowThePinnedRail() throws {
        var state = StudyProgramHomeScreen.State.populated
        let count = 12
        state.dayCount = count
        state.lessonNumbers = Array(1...count)
        state.lessonTitles = (1...count).map { "Lesson \($0)" }
        state.lessonDurations = Array(repeating: "3 mins", count: count)
        state.lessonSlideImages = Array(repeating: [""], count: count)
        state.lessonSlideLabels = Array(repeating: ["Slide"], count: count)

        let box = ProxyBox()
        let map = UI2ElementMap()
        let root = ScrollViewReader { proxy in
            ScrollView(.vertical) {
                StudyProgramHomeScreen(state: state, showsHeader: false)
                    .ui2ElementMap(map)
            }
            .onAppear { box.proxy = proxy }
        }
        let host = UIHostingController(rootView: AnyView(root))
        host.safeAreaRegions = []
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        window.rootViewController = host
        window.makeKeyAndVisible()
        addTeardownBlock { window.isHidden = true }
        host.view.frame = window.bounds
        settle(host)

        let day = 6
        let name = "C-063 LessonCard \(day)"
        let card = try XCTUnwrap(map.elements.first { $0.name.hasPrefix(name) }, "no \(name) in \(map.elements.map(\.name).prefix(40))")
        let scroll = try XCTUnwrap(scrollView(in: host.view))
        XCTAssertEqual(scroll.contentOffset.y, 0, accuracy: 1)

        box.proxy?.scrollTo(StudyProgramHomeScreen.lessonScrollID(day), anchor: .top)
        settle(host)

        // The pinned band is 64 tall (48 chips + 8 either side); the lesson starts 16 below it.
        let titleTop = card.rect.minY - scroll.contentOffset.y
        XCTAssertEqual(titleTop, 80, accuracy: 2, "the lesson's title row sits at y \(titleTop); under 64 it is behind the rail")
    }

    private func settle(_ host: UIViewController) {
        for _ in 0..<10 {
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.bounds.height > 500 { return scroll }
        for child in view.subviews { if let found = scrollView(in: child) { return found } }
        return nil
    }
}
