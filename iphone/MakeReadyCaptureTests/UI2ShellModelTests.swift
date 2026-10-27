import XCTest
import UIKit
@testable import MakeReady

final class UI2ShellModelTests: XCTestCase {
    func testEntryPoint() {
        let m = UI2ShellModel()
        XCTAssertEqual(m.tab, .home); XCTAssertEqual(m.section, .home); XCTAssertTrue(m.showsTopNav)
    }
    func testSectionsMatchTopNavContract() {
        XCTAssertEqual(UI2Section.allCases.map(\.rawValue), TopNav.designedTabs)
    }
    func testTopNavOnlyOnHome() {
        var m = UI2ShellModel()
        for tab in [TabBar.Tab.calendar, .search, .profile] { m.apply(.tab(tab)); XCTAssertFalse(m.showsTopNav) }
    }
    func testSectionSurvivesTabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.groups)); m.scrollOffset = 120
        m.apply(.tab(.search)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .groups); XCTAssertEqual(m.scrollOffset, 120)
    }
    func testRetapHomeReturnsToHomeSection() {
        var m = UI2ShellModel()
        m.apply(.section(.members)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }
    /// SPEC D14 (revised 2026-10-25): selecting a tab leaves the row as it is — an expanded
    /// row stays expanded (analysis §5.4).
    func testSelectingSectionKeepsExpansion() {
        var m = UI2ShellModel(); m.expansion = 1
        m.apply(.section(.invites))
        XCTAssertEqual(m.section, .invites); XCTAssertEqual(m.expansion, 1)
        m.expansion = 0
        m.apply(.section(.home))
        XCTAssertEqual(m.expansion, 0)
    }

    // MARK: - ui2-members-browse D1/D2/D20: per-tab push paths

    private let tony = UI2Destination.memberDetail(id: "m1", name: "Tony Stark")

    func testEveryTabStartsAtItsRoot() {
        let m = UI2ShellModel()
        XCTAssertEqual(UI2ShellModel.tabs, [.home, .calendar, .search, .profile])
        for tab in UI2ShellModel.tabs { XCTAssertEqual(m.path(for: tab), []) }
    }

    func testPushAndPopActOnTheNamedTabOnly() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.path(for: .profile), [])
        m.pop(on: .profile)                                    // nothing to pop: no-op
        XCTAssertEqual(m.path(for: .home), [tony])
        m.pop(on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        m.pop(on: .home)                                       // popping an empty path is safe
        XCTAssertEqual(m.path(for: .home), [])
    }

    /// D2: leaving a tab and coming back restores its pushed page.
    func testAPushedPageSurvivesATabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.apply(.tab(.search))
        XCTAssertEqual(m.tab, .search)
        XCTAssertEqual(m.path(for: .search), [])
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.section, .members)
    }

    /// D20: re-tapping the selected tab with a page pushed pops to the root and keeps the section.
    func testRetapWithAPushedPagePopsToTheRootOnly() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.push(.memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [])
        XCTAssertEqual(m.section, .members)
        XCTAssertEqual(m.tab, .home)
    }

    /// D20: with an empty path the re-tap keeps today's behaviour (`.home` section).
    func testRetapWithAnEmptyPathResetsTheSectionAsBefore() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }

    func testSetPathIsTheStackBinding() {
        var m = UI2ShellModel()
        m.setPath([tony], for: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.setPath([], for: .home)                              // the system edge-swipe pop writes this
        XCTAssertEqual(m.path(for: .home), [])
    }

    func testTopNavStaysARootPageFact() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertTrue(m.showsTopNav)                           // D1: no hide logic — the pushed page covers it
    }

    /// F2: the re-armed edge swipe may begin only when there is a page to pop.
    @MainActor
    func testPopGestureBeginsOnlyAboveTheRoot() {
        let nav = UINavigationController(rootViewController: UIViewController())
        let delegate = UI2PopGestureDelegate()
        delegate.navigationController = nav
        let gesture = UIScreenEdgePanGestureRecognizer()
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(gesture))
        nav.pushViewController(UIViewController(), animated: false)
        XCTAssertTrue(delegate.gestureRecognizerShouldBegin(gesture))
        XCTAssertFalse(UI2PopGestureDelegate().gestureRecognizerShouldBegin(gesture))   // no stack known
    }

    // MARK: - ui2-members-edit D2 / D13: the edit page on the member page

    private var editPhone: UI2Destination { .editMemberField(memberId: "m1", field: .phone) }

    /// D2: a field-row tap pushes its edit page above the member page.
    func testEditFieldPushesAboveTheMemberPage() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony, editPhone])
        XCTAssertNotEqual(editPhone, .editMemberField(memberId: "m1", field: .email))
        XCTAssertNotEqual(editPhone, .editMemberField(memberId: "m2", field: .phone))
    }

    /// D13: the success pop fires only while THIS edit page is still the last entry — a
    /// swipe-back, another page on top or a Home re-tap during the save leaves the stack alone.
    func testPopIfTopPopsOnlyWhenTheEditPageIsStillOnTop() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.popIfTop(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.popIfTop(editPhone, on: .home)                       // already swiped back: no-op
        XCTAssertEqual(m.path(for: .home), [tony])
        m.push(.editMemberField(memberId: "m1", field: .email), on: .home)
        m.popIfTop(editPhone, on: .home)                       // another page on top: no-op
        XCTAssertEqual(m.path(for: .home).count, 2)
        m.push(editPhone, on: .home)
        m.apply(.tab(.home))                                   // D20 re-tap empties the path
        m.popIfTop(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        m.push(editPhone, on: .home)
        m.popIfTop(editPhone, on: .profile)                    // another tab: no-op
        XCTAssertEqual(m.path(for: .home), [editPhone])
    }

    // MARK: - invite-member D11: the whole-flow pop

    func testPopToDepthDropsEveryInvitePageAboveTheEntry() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)                                         // depth 1 when "+" is tapped
        m.push(.inviteSelectGroup(returnDepth: 1), on: .home)
        m.push(.inviteMember(groupId: "g1", returnDepth: 1), on: .home)
        m.popTo(depth: 1, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
    }

    func testPopToDepthAtOrAboveTheCountIsANoOp() {
        var m = UI2ShellModel()
        m.push(.inviteMember(groupId: "g1", returnDepth: 0), on: .calendar)
        m.popTo(depth: 3, on: .calendar)
        XCTAssertEqual(m.path(for: .calendar), [.inviteMember(groupId: "g1", returnDepth: 0)])
        m.popTo(depth: 0, on: .calendar)
        XCTAssertEqual(m.path(for: .calendar), [])
        m.popTo(depth: -1, on: .calendar)                               // never negative
        XCTAssertEqual(m.path(for: .calendar), [])
    }


    // MARK: - ui2-groups-browse D8 / T17: the guarded replace

    /// D8: one path write — the top entry becomes the new page; back returns to what was below.
    func testReplaceTopSwapsOnlyTheLastEntry() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.replaceTop(editPhone, with: .memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        XCTAssertEqual(m.path(for: .home), [tony, .memberDetail(id: "m2", name: "Clark Kent")])
    }

    /// D8: swiped back mid-create (the form is no longer on top) → nothing is written.
    func testReplaceTopIsANoOpWhenTheExpectedPageIsNotOnTop() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.setPath([tony], for: .home)                                    // the system edge-swipe pop
        m.replaceTop(editPhone, with: .memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.replaceTop(editPhone, with: tony, on: .profile)                // empty tab: no-op
        XCTAssertEqual(m.path(for: .profile), [])
    }

    // MARK: - ui2-groups-browse D1/D3/D7/D8: the group routes

    private let walkGroup = UI2Destination.groupDetail(id: "g9", name: "Walk Test Group")

    /// D1: the group page is keyed by id and name, and pushes on the Home stack like any page.
    func testGroupDetailPushesOnTheHomeStack() {
        var m = UI2ShellModel()
        m.apply(.section(.groups))
        m.push(walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [walkGroup])
        XCTAssertNotEqual(walkGroup, .groupDetail(id: "g8", name: "Walk Test Group"))
        m.push(.memberDetail(id: "m1", name: "Tony Stark"), on: .home)   // D7: member row
        XCTAssertEqual(m.path(for: .home).count, 2)
    }

    /// D8: TopNav `+` pushes the form; success replaces it with the new group's page; back → Groups.
    func testCreateGroupIsReplacedByTheNewGroupsPage() {
        var m = UI2ShellModel()
        m.apply(.section(.groups))
        m.push(.createGroup, on: .home)
        m.replaceTop(.createGroup, with: walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [walkGroup])
        m.pop(on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        XCTAssertEqual(m.section, .groups)
    }

    /// D8: swiped back mid-create → the success writes nothing.
    func testCreateSwipedBackMidCreateWritesNothing() {
        var m = UI2ShellModel()
        m.push(.createGroup, on: .home)
        m.setPath([], for: .home)
        m.replaceTop(.createGroup, with: walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [])
    }

    /// D3 + home-dashboard-data D24: pull-to-refresh is wired for Home and Groups only.
    func testRefreshableSectionsAreHomeAndGroups() {
        var m = UI2ShellModel()
        XCTAssertEqual(m.refreshableSection, .home)
        m.apply(.section(.groups))
        XCTAssertEqual(m.refreshableSection, .groups)
        m.apply(.section(.members))
        XCTAssertNil(m.refreshableSection)
        m.apply(.section(.groups))
        m.apply(.tab(.search))
        XCTAssertNil(m.refreshableSection)
    }

    /// D7: a member page's group row opens that group (rows are `memberGroupsById` in order).
    func testMemberPageGroupRowOpensTheGroup() {
        let groups = [MemberGroupItem(id: "g1", name: "Young professionals"), MemberGroupItem(id: "g2", name: "The kids")]
        XCTAssertEqual(MemberProfileContainer.groupDestination(groups, row: 1), .groupDetail(id: "g2", name: "The kids"))
        XCTAssertNil(MemberProfileContainer.groupDestination(groups, row: 2))
        XCTAssertNil(MemberProfileContainer.groupDestination(nil, row: 0))
    }
}
