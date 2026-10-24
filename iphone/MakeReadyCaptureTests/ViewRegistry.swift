//
//  ViewRegistry.swift
//  MakeReadyCaptureTests
//
//  Maps fixture "view" keys to SwiftUI views.
//  Add new cases here as you add capture fixtures for more screens.
//

import SwiftUI
@testable import MakeReady
// UI 2.0 preview views are their own module (docs/ui2/preview-build.md §2), so their
// types carry no prefix — and six of them share a name with a 1.0 type in MakeReady.
// Every 2.0 reference below is therefore module-qualified: `UI2Preview.TextInput`, not
// `TextInput`. @testable, not a plain import, so the module stays internal-by-default.
@testable import UI2Preview

enum ViewRegistryError: Error {
    case unknownView(String)
}

// MARK: - CaptureCase (d2m designer-live-picks D5)

/// How a NORMAL preview frames a component: its master width (and height) pin, the specimen margin,
/// the alignment it fills the device width with, and whether the component hugs its content. A
/// design capture (`bare`) draws the component without any of it — the runner's one rule. The normal
/// preview always fills the device width on `color-layout-background` (OQ-PB-2 default).
struct PreviewFrame {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var marginEdges: Edge.Set = .all
    var margin: CGFloat = UI2Preview.Token.Space.pageMargin
    var alignment: Alignment = .center
    /// The component hugs its content (C-035 FilterChip): a bare capture lays it out `.fixedSize()`.
    var intrinsic: Bool = false
}

/// A case's bare component and its preview frame. `previewFrame` nil: an unconverted case, whose
/// `view` already carries its frame (D10 — framed, never bare).
struct CaptureCase {
    let view: AnyView
    let previewFrame: PreviewFrame?

    /// The normal preview — exactly the modifier chain a case wrote inline before it was converted.
    func previewView() -> AnyView {
        guard let f = previewFrame else { return view }
        var v = view
        if f.width != nil || f.height != nil { v = AnyView(v.frame(width: f.width, height: f.height)) }
        return AnyView(
            v.padding(f.marginEdges, f.margin)
                .frame(maxWidth: .infinity, alignment: f.alignment)
                .background(UI2Preview.Token.layoutBackground)
        )
    }
}

/// Where a converted case records itself while `buildCaptureView` runs. The part functions keep returning
/// `AnyView?` (the stack-overflow split), so a converted case returns `declareCase(view, frame)`, which
/// records its CaptureCase here and answers the normal preview.
/// ⚠️ `buildCaptureCase` keeps whatever declared LAST, so only a case's OWN return may call `declareCase` —
/// never a shared helper or a sub-view inside a screen case.
@MainActor enum CaptureCaseSink { static var declared: CaptureCase? }

@MainActor
func declareCase<V: View>(_ view: V, _ frame: PreviewFrame) -> AnyView {
    let built = CaptureCase(view: AnyView(view), previewFrame: frame)
    CaptureCaseSink.declared = built
    return built.previewView()
}

/// The fixture's CaptureCase: the one a converted case declared, else the unconverted case's framed view.
@MainActor
func buildCaptureCase(for fixture: CaptureFixture) throws -> CaptureCase {
    CaptureCaseSink.declared = nil
    defer { CaptureCaseSink.declared = nil }
    let framed = try buildCaptureView(for: fixture)
    return CaptureCaseSink.declared ?? CaptureCase(view: framed, previewFrame: nil)
}

// MARK: - Shared decoders for component.* card fixtures

/// Maps a small set of named colors used in component previews. Avoids
/// `Color(hex:)` (which the SwiftLint gate reserves for Colors.swift); unknown
/// names fall back to the component's own default.
func namedCaptureColor(_ name: String?) -> Color? {
    switch name?.lowercased() {
    case "purple": return Color.brandPrimary  // app shadows Color.purple → use the brand token
    case "green": return Color.green
    case "orange": return Color.orange
    case "blue": return Color.blue
    case "red": return Color.red
    default: return nil
    }
}

/// Builds a `CardImageStyle` from a fixture's loose image-style block.
func makeCaptureImageStyle(_ s: CaptureImageStyle?, defaultIcon: String) -> CardImageStyle {
    guard let s else { return .icon(systemName: defaultIcon) }
    switch s.kind {
    case "photo":
        return .photo(imageURL: s.url ?? "")
    case "dateDisplay":
        return .dateDisplay(day: s.day ?? 1, month: s.month ?? "")
    case "timeDisplay":
        return .timeDisplay(time: s.time ?? "", period: s.period ?? "")
    default:
        return .icon(systemName: s.systemName ?? defaultIcon,
                     backgroundColor: namedCaptureColor(s.background),
                     foregroundColor: namedCaptureColor(s.foreground))
    }
}

/// Builds `[DataItem]` metadata chips. The first non-nil of
/// (badge, number, label+value, icon+value) picks the flavor.
func makeCaptureDataItems(_ raw: [CaptureDataItem]?) -> [DataItem] {
    (raw ?? []).map { d in
        if let badge = d.badge { return DataItem(badge: badge) }
        if let number = d.number { return DataItem(number: number, label: d.label ?? "") }
        if let icon = d.icon { return DataItem(icon: icon, value: d.value ?? "", isPurple: d.isPurple ?? false) }
        if let label = d.label { return DataItem(label: label, value: d.value ?? "") }
        return DataItem(icon: "circle", value: d.value ?? "")
    }
}

/// Maps a fixture status string to CardStatus (nil when absent/unknown).
func makeCaptureStatus(_ s: String?) -> CardStatus? {
    switch s {
    case "pending": return .pending
    case "new": return .new
    case "selected": return .selected
    case "confirmed": return .confirmed
    default: return nil
    }
}

// Deterministic date parsing for fixtures — captures must never depend on "now".
private let captureISODateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
private let captureYMDDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// Parses an ISO8601 or `yyyy-MM-dd` fixture string to a Date (nil if absent/invalid).
func makeCaptureDateOptional(_ s: String?) -> Date? {
    guard let s else { return nil }
    return captureISODateFormatter.date(from: s) ?? captureYMDDateFormatter.date(from: s)
}

/// Non-optional variant — falls back to a fixed epoch so layout stays deterministic.
func makeCaptureDate(_ s: String?) -> Date {
    makeCaptureDateOptional(s) ?? Date(timeIntervalSince1970: 0)
}

/// Builds the SwiftUI view for a given fixture, wrapping it with
/// the required environment objects (AuthManager, OverlayManager).
///
/// A thin dispatcher: the out-of-line cases are routed here so their view's type-metadata
/// resolution runs WITHOUT `buildCaptureViewInline`'s Debug stack frame beneath it — that frame
/// is large enough that a deep SwiftUI body type overflows the thread (C-085 build, 2026-09-30).
@MainActor
func buildCaptureView(for fixture: CaptureFixture) throws -> AnyView {
    switch fixture.view {
    case "component.ui2.C-037": return try buildUI2C037(fixture)
    case "component.ui2.C-083": return try buildUI2C083(fixture)
    case "component.ui2.C-084": return try buildUI2C084(fixture)
    case "component.ui2.C-085": return try buildUI2C085(fixture)
    case "component.ui2.C-086": return try buildUI2C086(fixture)
    case "component.ui2.C-088": return try buildUI2C088(fixture)
    case "component.ui2.C-089": return try buildUI2C089(fixture)
    case "component.ui2.C-090": return try buildUI2C090(fixture)
    case "component.ui2.C-092": return try buildUI2C092(fixture)
    case "component.ui2.C-093": return try buildUI2C093(fixture)
    case "component.ui2.C-104": return try buildUI2C104(fixture)
    case "screen.2.0.home-kpi-picker": return try buildScreenHomeKpiPicker(fixture)
    case "screen.2.0.login": return try buildScreenLogin(fixture)
    case "screen.2.0.request-detail": return try buildScreenRequestDetail(fixture)
    default: return try buildCaptureViewInline(for: fixture)
    }
}

@MainActor @inline(never)
private func buildCaptureViewInline(for fixture: CaptureFixture) throws -> AnyView {
    let authManager = makeMockAuthManager(from: fixture.auth)

    // One switch per part, each out of line with its own stack frame. In Debug (-Onone)
    // every case's locals get their own stack slot, and a single switch over every
    // fixture grew past the 8 MB main-thread stack (EXC_BAD_ACCESS "Thread stack size
    // exceeded" on entry, 2026-09-30). Add new cases to the LAST part; start a new part
    // once it holds 25.
    if let view = try buildCaptureViewPart1(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart2(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart3(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart4(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart5(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart6(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart7(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart8(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart9(fixture, authManager: authManager) { return view }
    if let view = try buildCaptureViewPart10(fixture, authManager: authManager) { return view }
    throw ViewRegistryError.unknownView(fixture.view)
}

/// Part 1 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart1(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.card-study":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.card-study: missing state.component")
        }
        let status: CardStatus = {
            switch c.status {
            case "pending": return .pending
            case "new": return .new
            default: return .confirmed
            }
        }()
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: c.iconSystemName ?? "book.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = makeCaptureDataItems(c.metadata)
        let data = CardStudyData(
            id: "capture-card-study",
            title: c.title ?? "",
            description: c.description,
            type: c.type,
            imageStyle: imageStyle,
            metadata: metadata,
            status: status,
            onTap: nil
        )
        return AnyView(CardStudy(data: data).padding(16))
    case "component.GroupCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupCard: missing state.component")
        }
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: "person.2.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = makeCaptureDataItems(c.metadata)
        let data = CardGroupData(
            id: "capture-group-card",
            title: c.title ?? "",
            imageStyle: imageStyle,
            metadata: metadata,
            isSelected: c.selected?.boolValue ?? false
        )
        if (c.size?.stringValue ?? "Row") == "Mini" {
            return AnyView(CardGroupMini(data: data).padding(16))
        }
        return AnyView(CardGroup(data: data).padding(16))
    case "component.CardEvent":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEvent: missing state.component")
        }
        let data = CardEventData(
            id: "capture-card-event",
            title: c.title ?? "",
            subtitle: c.subtitle,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "calendar"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardEvent(data: data).padding(16))
    case "pages.login":
        return AnyView(
            LoginView()
                .environment(authManager)
        )
    case "pages.home":
        return AnyView(
            MainView()
                .environment(authManager)
        )
    case "pages.group-home":
        // Group is seeded into AppState by setupCaptureState; GroupHomePage.init
        // reads AppState.groups[groupId] for an immediate (non-loading) first paint.
        let groupId = fixture.state?.groupId
            ?? fixture.state?.groups?.first?.id
            ?? "group-1"
        return AnyView(
            GroupHomePage(
                overlayManager: OverlayManager(),
                groupId: groupId,
                onDismiss: {}
            )
            .environment(authManager)
        )
    // Leader main screens (compare tool, iPhone-first). MemberHomePage applies
    // `pendingSubTab` in .onAppear, so a constant binding selects the tab for the
    // static capture (0 = Groups, 1 = Members, 2 = Enrolled). Data is seeded into
    // AppState by setupCaptureState from the fixture (groups / enrollments).
    case "pages.groups":
        return AnyView(
            MemberHomePage(
                overlayManager: OverlayManager(),
                avatarURL: nil,
                pendingSubTab: .constant(0)
            )
            .environment(authManager)
        )
    case "pages.groups-enrolled":
        return AnyView(
            MemberHomePage(
                overlayManager: OverlayManager(),
                avatarURL: nil,
                pendingSubTab: .constant(2)
            )
            .environment(authManager)
        )
    // MainLibrary defaults to the Programs tab (activeTab 0); programs are read
    // from AppState (seeded from the fixture).
    case "pages.study-programs":
        return AnyView(
            MainLibrary(overlayManager: OverlayManager())
                .environment(authManager)
        )
    // GlobalSearchPage indexes the seeded programs/groups in AppState; the
    // capture shows its resting (recents/empty) state.
    case "pages.search":
        return AnyView(
            GlobalSearchPage(
                overlayManager: OverlayManager(),
                initialQuery: fixture.state?.searchQuery
            )
            .environment(authManager)
        )
    // MainHome Activity tab (initialTab: 1). Activity-log content needs its own
    // seeding (follow-up); the capture shows the tab + its empty/resting state.
    case "pages.activity":
        return AnyView(
            MainHome(overlayManager: OverlayManager(), avatarURL: nil, initialTab: 1)
                .environment(authManager)
        )
    // MainLibrary Media tab (initialTab: 1). Media items need their own seeding
    // (follow-up); the capture shows the Media tab + its empty/resting state.
    case "pages.media":
        return AnyView(
            MainLibrary(overlayManager: OverlayManager(), initialTab: 1)
                .environment(authManager)
        )
    // MainCalendar (no tabs). Calendar events need their own seeding (follow-up);
    // the capture shows the month grid + resting state.
    case "pages.calendar":
        return AnyView(
            MainCalendar(overlayManager: OverlayManager(), avatarURL: nil)
                .environment(authManager)
        )
    // MemberHomePage Members tab (pendingSubTab: 1). Org-member content needs its
    // own seeding (follow-up); the capture shows the Members tab + resting state.
    case "pages.group-members":
        return AnyView(
            MemberHomePage(
                overlayManager: OverlayManager(),
                avatarURL: nil,
                pendingSubTab: .constant(1)
            )
            .environment(authManager)
        )
    case "pages.create-program":
        return AnyView(
            CreateProgramPage(overlayManager: OverlayManager())
                .environment(authManager)
        )
    case "pages.edit-read-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let lessonId = fixture.state?.lessonId ?? "capture-lesson-0"
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-read-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditReadActivityPage(
                activity: activity,
                lessonId: lessonId,
                programId: programId,
                onCancel: {},
                onSave: { _ in }
            )
            .environment(OverlayManager())
            .environment(authManager)
        )
    case "pages.edit-exegesis-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-exegesis-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditExegesisActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: {}
            )
            .environment(OverlayManager())
            .environment(authManager)
        )
    case "pages.program-home":
        let programId = fixture.state?.programId ?? "capture-prog-0"
        var coverImage: UIImage? = nil
        if let imagePath = fixture.state?.programCoverImagePath {
            let fullPath = (CaptureFixtureLoader.captureRootPath() as NSString).appendingPathComponent(imagePath)
            coverImage = UIImage(contentsOfFile: fullPath)
        }
        return AnyView(
            ProgramHomePage(
                overlayManager: OverlayManager(),
                programId: programId,
                onShowAddActivityMenu: nil,
                initialCoverImage: coverImage,
                initialTab: fixture.state?.selectedTab ?? 0
            )
            .environment(authManager)
        )
    case "pages.study-invite":
        guard let seed = fixture.state?.studyInvite else {
            throw ViewRegistryError.unknownView("pages.study-invite: missing state.studyInvite")
        }
        return AnyView(
            StudyInvitePage(
                scheduleId: seed.scheduleId,
                dayNumber: seed.dayNumber,
                studyName: seed.programName,
                onDismiss: {}
            )
            .environment(authManager)
        )
    case "pages.member-request-respond":
        guard let seed = fixture.state?.respond else {
            throw ViewRegistryError.unknownView("pages.member-request-respond: missing state.respond")
        }
        return AnyView(
            MemberRequestRespondModal(
                memberName: seed.memberName,
                groupName: seed.groupName,
                requestDate: Date(timeIntervalSince1970: seed.requestedAt ?? 1_700_000_000),
                onApprove: {},
                onReject: {},
                onCancel: {}
            )
            // The modal animates its own opacity from 0 on .onAppear — freeze
            // so the snapshot isn't blank (same fix as pages.add-activity-menu).
            .transaction { $0.disablesAnimations = true }
        )
    case "pages.change-membership":
        guard let seed = fixture.state?.changeMembership else {
            throw ViewRegistryError.unknownView("pages.change-membership: missing state.changeMembership")
        }
        let transferCandidates = (seed.candidates ?? []).map {
            ChangeMembershipModal.TransferGroup(
                id: $0.id,
                name: $0.name,
                coverImageUrl: $0.coverImageUrl,
                memberCount: $0.memberCount,
                activeStudies: $0.activeStudies
            )
        }
        return AnyView(
            ChangeMembershipModal(
                memberName: seed.memberName,
                groupName: seed.groupName,
                mode: seed.mode == "removed" ? .removed : .joined,
                transferCandidates: transferCandidates,
                onRemoveConfirmed: {},
                onRejoinConfirmed: {},
                onTransferConfirmed: { _ in },
                onCancel: {}
            )
            .transaction { $0.disablesAnimations = true }
        )
    // EnrollmentFlowModal (.enrollmentFlow / .programEnrollmentFlow) — the
    // 3-panel enrollment wizard. Only panel 0 is seedable (step index,
    // calendar selection and confirm state are private @State):
    // enrollmentFlowEntry "group" → Select Program panel (preselected group =
    // first seeded group); "program" → Select Group panel (preselected
    // program = first seeded program). existingEnrollments seeds [] so the
    // program cards render enabled (isEnrollmentDataLoaded).
    case "pages.enrollment-flow":
        let entry = fixture.state?.enrollmentFlowEntry ?? "group"
        if entry == "program" {
            guard let program = AppState.shared.orderedPrograms.first else {
                throw ViewRegistryError.unknownView("pages.enrollment-flow: no seeded programs")
            }
            return AnyView(
                EnrollmentFlowModal(
                    preselectedGroup: nil,
                    preselectedProgram: program,
                    onDismiss: {},
                    onComplete: { _, _, _ in }
                )
                .environment(authManager)
                .transaction { $0.disablesAnimations = true }
            )
        } else {
            guard let group = AppState.shared.orderedGroups.first else {
                throw ViewRegistryError.unknownView("pages.enrollment-flow: no seeded groups")
            }
            return AnyView(
                EnrollmentFlowModal(
                    preselectedGroup: group,
                    preselectedProgram: nil,
                    existingEnrollments: [],
                    existingLessonDates: [],
                    onDismiss: {},
                    onComplete: { _, _, _ in }
                )
                .environment(authManager)
                .transaction { $0.disablesAnimations = true }
            )
        }
    case "pages.edit-day":
        let lessonId = fixture.state?.lessonId ?? "capture-lesson-0"
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let lesson = AppState.shared.lessons[lessonId] else {
            throw ViewRegistryError.unknownView("pages.edit-day: lesson '\(lessonId)' not in AppState")
        }
        return AnyView(
            EditDay(
                isPresented: .constant(true),
                programId: programId,
                lesson: lesson,
                onLessonUpdated: { _ in },
                onShowAddActivityMenu: nil
            )
            .environment(authManager)
        )
    case "pages.video-activity-picker":
        return AnyView(
            VideoActivityPicker(
                onDismiss: {},
                onVideoSelected: { _ in }
            )
            .environment(authManager)
        )
    case "pages.edit-youtube-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-youtube-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditYouTubeActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _ in }
            )
            .environment(authManager)
        )
    case "pages.edit-user-input-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-user-input-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditUserInputActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _, _ in }
            )
            .environment(authManager)
        )
    default:
        return nil
    }
}

/// Part 2 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart2(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.CardVideo":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardVideo: missing state.component")
        }
        let data = CardVideoData(
            id: "capture-card-video",
            title: c.title ?? "",
            description: c.description,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "play.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardVideo(data: data).padding(16))
    case "component.CardVideoMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardVideoMini: missing state.component")
        }
        let data = CardVideoData(
            id: "capture-card-video-mini",
            title: c.title ?? "",
            description: c.description,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "play.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardVideoMini(data: data).padding(16))
    case "component.CardStudyMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardStudyMini: missing state.component")
        }
        let data = CardStudyData(
            id: "capture-card-study-mini",
            title: c.title ?? "",
            description: c.description,
            type: c.type,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "book.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardStudyMini(data: data).padding(16))
    case "component.CardStudySelectable":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardStudySelectable: missing state.component")
        }
        let data = CardStudySelectableData(
            id: "capture-card-study-selectable",
            title: c.title ?? "",
            description: c.description,
            lessonCount: c.count ?? 0,
            imageURL: c.imageUrl,
            isSelected: c.selected?.boolValue ?? false,
            isPublished: c.isPublished ?? true,
            enrolledUntilDate: nil,
            isDisabled: false
        )
        return AnyView(CardStudySelectable(data: data).padding(16))
    case "component.CardEventMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEventMini: missing state.component")
        }
        let data = CardEventData(
            id: "capture-card-event-mini",
            title: c.title ?? "",
            subtitle: c.subtitle,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "calendar"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardEventMini(data: data).padding(16))
    case "component.CardMember":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardMember: missing state.component")
        }
        let data = CardMemberData(
            id: "capture-card-member",
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl,
            metadata: makeCaptureDataItems(c.metadata),
            groups: c.groups ?? []
        )
        if c.variant == "invite" {
            return AnyView(
                CardMember(data: data) {
                    ActionButton(label: "Invite", variant: .purple) {}
                }
                .padding(16)
            )
        }
        return AnyView(CardMember(data: data).padding(16))
    case "component.CardContact":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardContact: missing state.component")
        }
        let data = CardContactData(
            id: "capture-card-contact",
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl
        )
        if c.variant == "invite" {
            return AnyView(
                CardContact(data: data) {
                    ActionButton(label: "Invite", variant: .purple) {}
                }
                .padding(16)
            )
        }
        return AnyView(CardContact(data: data).padding(16))
    case "component.CardActivityType":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardActivityType: missing state.component")
        }
        let catMode: CardActivityTypeMode = (c.mode == "grid") ? .grid : .list
        let catImage: CardActivityTypeImage = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(url: cover)
            }
            return .icon(
                systemName: c.imageStyle?.systemName ?? "book.fill",
                backgroundColor: namedCaptureColor(c.imageStyle?.background) ?? Color.brandPrimary
            )
        }()
        let catCard = CardActivityType(
            title: c.title ?? "",
            description: c.description,
            image: catImage,
            mode: catMode,
            available: c.available ?? true,
            onTap: {}
        )
        if catMode == .grid {
            return AnyView(catCard.frame(width: 120).padding(16))
        }
        return AnyView(catCard.padding(16))
    case "component.CardActivity":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardActivity: missing state.component")
        }
        let entry = ActivityLogEntry(
            id: "capture-card-activity",
            category: c.category ?? "AUTH",
            activityType: "",
            status: c.status ?? "SUCCESS",
            message: c.text ?? "",
            userId: nil, memberId: nil, groupId: nil, eventId: nil,
            enrollmentId: nil, organizationId: nil, metadata: nil,
            createdAt: c.createdAt ?? "2026-01-30T12:00:00Z"
        )
        return AnyView(CardActivity(entry: entry).padding(16))
    case "component.CardLessonActivity":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardLessonActivity: missing state.component")
        }
        let rawType = c.type ?? "READ"
        let isVideoActivity = rawType == "VIDEO" || rawType == "YOUTUBE"
        let isNewActivity = c.status == "new"
        let laImageStyle: CardImageStyle = {
            if let s = c.imageStyle, s.kind == "photo" {
                return .photo(imageURL: s.url ?? "")
            }
            return .icon(
                systemName: ActivityStyle.icon(forRawType: rawType),
                backgroundColor: isNewActivity ? nil : ActivityStyle.color(forRawType: rawType),
                foregroundColor: isNewActivity ? ActivityStyle.color(forRawType: rawType)
                                               : ActivityStyle.iconColor(forRawType: rawType)
            )
        }()
        let laData = CardLessonActivityData(
            id: "capture-card-lesson-activity",
            title: c.title ?? "",
            description: c.description,
            type: rawType,
            rawActivityType: rawType,
            imageStyle: laImageStyle,
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            isVideo: isVideoActivity,
            estimatedMinutes: c.estimatedMinutes
        )
        let laSize: CardLessonActivitySize = (c.size?.stringValue == "small") ? .small : .default
        return AnyView(
            CardLessonActivity(data: laData, size: laSize, showAnimatedBorder: isNewActivity)
                .padding(16)
        )
    case "component.CardLesson":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardLesson: missing state.component")
        }
        func mapLessonActivityStatus(_ s: String?) -> LessonActivityStatus {
            switch s {
            case "complete": return .complete
            case "incomplete": return .incomplete
            case let v? where v.hasPrefix("percent:"):
                return .percentComplete(Double(v.dropFirst("percent:".count)) ?? 0)
            default: return .default
            }
        }
        func mapLessonActivities(_ raw: [CaptureLessonActivity]?) -> [LessonActivityData] {
            (raw ?? []).map { a in
                let type = a.type ?? "READ"
                // Lesson-mode activities omit `icon` and derive it from `type`;
                // planning-mode activities ship an explicit SF Symbol name.
                let icon = a.icon.flatMap { $0.isEmpty ? nil : $0 } ?? ActivityStyle.icon(forRawType: type)
                return LessonActivityData(
                    icon: icon,
                    type: type,
                    title: a.title ?? "",
                    label: a.title,
                    isConfigured: a.isConfigured ?? true,
                    status: mapLessonActivityStatus(a.status)
                )
            }
        }
        let lessonMode: CardLessonMode = {
            switch c.mode {
            case "lesson": return .lesson
            case "progress": return .progress
            case "lessonList": return .lessonList
            default: return .planning
            }
        }()
        let lessonStatus: CardLessonStatus? = {
            guard let s = c.lessonStatus else { return nil }
            if s == "complete" { return .complete }
            if s == "next" { return .next }
            if s.hasPrefix("upcoming:") { return .upcoming(String(s.dropFirst("upcoming:".count))) }
            return nil
        }()
        let lessonSections: [SectionProgress]? = c.sections.map { secs in
            secs.map { SectionProgress(
                name: $0.name,
                completedAt: ($0.completed ?? false) ? Date(timeIntervalSince1970: 1_769_000_000) : nil
            ) }
        }
        let lessonData = CardLessonData(
            id: "capture-card-lesson",
            day: c.day?.intValue ?? 1,
            mode: lessonMode,
            activities: mapLessonActivities(c.activities),
            title: c.title,
            description: c.description,
            date: makeCaptureDateOptional(c.date?.string),
            progress: c.progress,
            sections: lessonSections,
            status: lessonStatus,
            coverImageUrl: c.coverUrl,
            estimatedMinutes: c.estimatedMinutes,
            isReleased: c.isReleased ?? false
        )
        return AnyView(CardLesson(data: lessonData).padding(16))
    case "component.ScheduledLessonCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ScheduledLessonCard: missing state.component")
        }
        let schedActivities: [ScheduledActivity] = (c.activities ?? []).enumerated().map { idx, a in
            let title = (a.title?.isEmpty == false) ? a.title : nil
            return ScheduledActivity(
                id: "capture-sched-act-\(idx)",
                lessonId: "capture-sched-lesson",
                type: a.type ?? "SCRIPTURE",
                title: title,
                passageReference: title,
                orderNumber: idx + 1
            )
        }
        let day: TimeInterval = 24 * 60 * 60
        let scheduledDate: Date
        let explicitCompleted: Bool?
        switch c.status {
        case "completed":
            scheduledDate = Date().addingTimeInterval(-7 * day)
            explicitCompleted = true
        case "today":
            scheduledDate = Date()
            explicitCompleted = nil
        default:
            scheduledDate = Date().addingTimeInterval(7 * day)
            explicitCompleted = nil
        }
        let schedule = LessonSchedule(
            id: "capture-schedule",
            enrollmentId: "capture-enrollment",
            lessonId: "capture-sched-lesson",
            scheduledDate: scheduledDate,
            isCompleted: explicitCompleted,
            completedAt: explicitCompleted == true ? Date().addingTimeInterval(-6 * day) : nil,
            lesson: LessonWithActivities(
                id: "capture-sched-lesson",
                studyProgramId: "capture-prog-0",
                dayNumber: c.dayNumber ?? 1,
                activities: schedActivities
            )
        )
        return AnyView(ScheduledLessonCard(schedule: schedule).padding(16))
    case "component.CardEnrolled":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEnrolled: missing state.component")
        }
        let data = CardEnrolledData(
            id: "capture-card-enrolled",
            studyTitle: c.studyTitle ?? c.title ?? "",
            groupName: c.groupName ?? "",
            startDate: makeCaptureDate(c.startDate),
            endDate: makeCaptureDate(c.endDate),
            lessonsLeft: c.lessonsLeft,
            studyImageURL: c.studyImageURL,
            groupImageURL: c.groupImageURL,
            onTap: nil
        )
        return AnyView(CardEnrolled(data: data).padding(16))
    case "component.CardProgramFull":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardProgramFull: missing state.component")
        }
        let data = CardProgramFullData(
            id: "capture-card-program-full",
            title: c.title ?? "",
            description: c.description,
            coverImageUrl: c.coverUrl,
            tags: c.tags ?? [],
            days: c.days?.duration ?? 0,
            enrollmentCount: c.enrollmentCount,
            authorName: c.authorName,
            createdAt: makeCaptureDate(c.createdAt),
            isPublished: c.isPublished ?? false,
            onTap: nil
        )
        return AnyView(CardProgramFull(data: data).padding(16))
    case "component.UpcomingLessonCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.UpcomingLessonCard: missing state.component")
        }
        let upcomingActivities: [ScheduledActivity] = (c.activities ?? []).enumerated().map { idx, a in
            let type = a.type ?? "SCRIPTURE"
            return ScheduledActivity(
                id: "capture-activity-\(idx)",
                lessonId: "capture-lesson-0",
                type: type,
                passageReference: (type == "SCRIPTURE" || type == "SOAP") ? (a.title ?? "Genesis 1:1") : nil,
                videoId: type == "VIDEO" ? "capture-video" : nil,
                prayerPrompt: type == "PRAYER" ? (a.title ?? "Pray") : nil,
                notes: type == "REFLECTION" ? (a.title ?? "Reflect") : nil,
                orderNumber: idx + 1
            )
        }
        let upcomingSchedule = LessonSchedule(
            id: "capture-schedule-0",
            enrollmentId: "capture-enrollment-0",
            lessonId: "capture-lesson-0",
            scheduledDate: makeCaptureDate(c.date?.string),
            isCompleted: nil,
            completedAt: nil,
            lesson: LessonWithActivities(
                id: "capture-lesson-0",
                studyProgramId: "capture-prog-0",
                dayNumber: c.dayNumber ?? 1,
                activities: upcomingActivities
            )
        )
        return AnyView(
            UpcomingLessonCard(
                schedule: upcomingSchedule,
                programName: c.programName ?? c.title ?? "",
                coverImageUrl: c.coverUrl,
                onTap: nil
            ).padding(16)
        )
    case "component.EnrollmentCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.EnrollmentCard: missing state.component")
        }
        let enrollment = EnrollmentWithProgram(
            id: "capture-enrollment-0",
            groupId: "capture-group-0",
            studyProgramId: "capture-prog-0",
            startDate: makeCaptureDate(c.startDate),
            endDate: makeCaptureDate(c.endDate),
            studyProgram: StudyProgramSummary(
                id: "capture-prog-0",
                name: c.title ?? "Study Program",
                description: nil,
                days: c.days?.duration ?? 0,
                coverImageUrl: c.coverUrl
            ),
            isActive: !(c.isCompleted ?? false)
        )
        return AnyView(EnrollmentCard(enrollment: enrollment, onTap: nil).padding(16))
    case "component.CardMediaFull":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardMediaFull: missing state.component")
        }
        let item = MediaLibraryItem(
            id: "capture-media-full",
            title: c.title ?? "",
            description: nil,
            url: c.imageUrl ?? "",
            type: c.type ?? "video",
            mimeType: nil,
            fileSize: nil,
            thumbnailUrl: nil,
            uploadStatus: "ready",
            duration: c.durationSeconds,
            tags: [],
            usageCount: c.count ?? 0,
            uploader: nil,
            video: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return AnyView(CardMediaFull(item: item).frame(width: 120).padding(16))
    case "component.CardSearchResult":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardSearchResult: missing state.component")
        }
        return AnyView(
            CardSearchResult(
                title: c.title ?? "",
                subtitle: c.subtitle,
                timestamp: c.timeAgo,
                imageURL: c.imageUrl,
                firstName: c.firstName,
                lastName: c.lastName,
                sfSymbol: c.iconSystemName ?? "doc.fill",
                isMember: c.isMember ?? false,
                isVideo: c.isVideo ?? false,
                showChevron: c.showChevron ?? true,
                highlightQuery: c.highlightQuery ?? "",
                onTap: {}
            )
            .padding(16)
        )
    case "component.CardBibleSearchResult":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardBibleSearchResult: missing state.component")
        }
        return AnyView(
            CardBibleSearchResult(
                reference: c.passage ?? "",
                text: c.text ?? "",
                title: c.title,
                summary: c.description,
                onTap: nil
            )
            .padding(16)
        )
    case "component.GroupPostCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupPostCard: missing state.component")
        }
        let postType: PostType = {
            switch c.type?.lowercased() {
            case "event": return .event
            case "poll": return .poll
            case "video": return .video
            case "welcome": return .welcome
            default: return .announcement
            }
        }()
        let postCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
            .addingTimeInterval(-Double(c.createdSecondsAgo ?? 0))
        var postEventDate: Date? = nil
        if postType == .event, let pday = c.day?.intValue {
            let months = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                          "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
            var comps = DateComponents()
            comps.year = c.dayNumber ?? 2025
            comps.month = months[(c.month ?? "").uppercased()] ?? 1
            comps.day = pday
            let hour12 = Int((c.time ?? "0:00").split(separator: ":").first ?? "0") ?? 0
            let minute = Int((c.time ?? "0:00").split(separator: ":").last ?? "0") ?? 0
            let isPM = (c.period ?? "").lowercased() == "pm"
            comps.hour = isPM && hour12 < 12 ? hour12 + 12 : hour12
            comps.minute = minute
            postEventDate = Calendar.current.date(from: comps)
        }
        let post = GroupPost(
            id: "capture-group-post",
            groupId: "capture-group",
            authorId: postType == .welcome ? nil : "capture-author",
            authorName: c.authorName ?? "",
            authorAvatarUrl: c.imageUrl,
            type: postType,
            content: c.text ?? "",
            title: c.title,
            imageUrl: c.images?.first,
            enrollmentId: nil,
            createdAt: postCreatedAt,
            updatedAt: postCreatedAt,
            viewCount: c.count,
            shareCount: Int(c.value ?? ""),
            pollOptions: nil,
            videoUrl: nil,
            eventDate: postEventDate,
            eventLocation: nil,
            eventTitle: c.subtitle,
            attendeeCount: c.memberCount
        )
        return AnyView(GroupPostCard(post: post).padding(16))
    // MARK: - Button

    case "component.ActionButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ActionButton: missing state.component")
        }
        let variant: ActionButtonVariant = {
            switch c.variant {
            case "purple": return .purple
            case "purpleIcon": return .purpleIcon
            case "white": return .white
            case "whiteIcon": return .whiteIcon
            case "whitePurple": return .whitePurple
            case "swipeLarge": return .swipeLarge
            case "circleBlur": return .circleBlur
            default: return .white
            }
        }()
        let actionButton: ActionButton = {
            if let label = c.label {
                return ActionButton(label: label, icon: c.icon, variant: variant, action: {})
            }
            return ActionButton(icon: c.icon ?? "questionmark", variant: variant, action: {})
        }()
        return AnyView(actionButton.padding(16))
    case "component.BoxButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.BoxButton: missing state.component")
        }
        let boxVariant: BoxButtonVariant = {
            switch c.variant {
            case "secondary": return .secondary
            case "destructive": return .destructive
            case "disabled": return .disabled
            default: return .primary
            }
        }()
        let boxStyle: BoxButtonStyle = c.style == "border" ? .border : .solid
        let boxSize: BoxButtonSize = {
            switch c.size?.stringValue {
            case "lg": return .lg
            case "sm": return .sm
            default: return .md
            }
        }()
        let boxIconPosition: BoxButtonIconPosition = {
            switch c.iconPosition {
            case "left": return .left
            case "right": return .right
            case "none": return .none
            default: return c.icon != nil ? .left : .none
            }
        }()
        return AnyView(
            BoxButton(
                action: {},
                label: c.label,
                icon: c.icon,
                iconPosition: boxIconPosition,
                variant: boxVariant,
                style: boxStyle,
                size: boxSize,
                fullWidth: c.fullWidth ?? false
            ).padding(16)
        )
    // ===== Display =====
    // MARK: - Display

    case "component.Alert":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Alert: missing state.component")
        }
        let alertVariant: AlertVariant = (c.variant == "critical") ? .critical : .warning
        return AnyView(
            Alert(message: c.message ?? c.text ?? "", variant: alertVariant)
                .padding(16)
        )
    case "component.AlphabetScrubber":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.AlphabetScrubber: missing state.component")
        }
        let scrubberLetters = (c.letters?.isEmpty == false)
            ? c.letters!
            : Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }
        return AnyView(
            AlphabetScrubber(letters: scrubberLetters, onLetterTap: { _ in })
                .frame(height: 360)
                .padding(16)
        )
    case "component.Avatar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Avatar: missing state.component")
        }
        let avatarSize: AvatarSize = {
            switch c.size?.stringValue {
            case "xs": return .xs
            case "sm": return .sm
            case "md": return .md
            case "lg": return .lg
            case "xl": return .xl
            case "xxl": return .xxl
            default: return .md
            }
        }()
        return AnyView(
            Avatar(
                imageURL: c.imageUrl,
                initials: c.initials,
                size: avatarSize
            )
            .padding(16)
        )
    default:
        return nil
    }
}

/// Part 3 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart3(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.DialogOverlay":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.DialogOverlay: missing state.component")
        }
        let dialogButtons: [DialogButtonConfig] = (c.buttons ?? []).map { b in
            let style: DialogButtonStyle = (b.style == "secondary") ? .secondary : .primary
            return DialogButtonConfig(b.label ?? "", style: style, action: {})
        }
        return AnyView(
            DialogOverlay(
                isPresented: .constant(true),
                title: c.title,
                message: c.message,
                buttons: dialogButtons
            )
            .frame(height: 360)
        )
    case "component.FullScreenImageViewer":
        // The viewer takes a UIImage; remote fixture URLs can't be loaded
        // synchronously in a deterministic capture, so render the chrome over a
        // stand-in SF Symbol image.
        return AnyView(
            FullScreenImageViewer(image: UIImage(systemName: "photo.fill"))
                .frame(height: 480)
        )
    case "component.GroupSelectorSheet":
        // Self-contained: its GroupFixtureManager @StateObject hardcodes a default
        // group list, so it renders standalone. We only supply the selection binding
        // and bound the NavigationStack to a sheet-like height for the snapshot.
        return AnyView(
            GroupSelectorSheet(selectedGroup: .constant(nil))
                .frame(width: 393, height: 640)
        )
    case "component.InfoPanel":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.InfoPanel: missing state.component")
        }
        let infoMode: InfoPanelMode = (c.mode == "data") ? .data : .keyValue
        let infoItems: [InfoPanelItem] = (c.items ?? []).map { item in
            InfoPanelItem(label: item.label ?? "", value: item.value ?? "")
        }
        return AnyView(
            InfoPanel(items: infoItems, mode: infoMode)
                .padding(16)
        )
    // SKIPPED component.InviteQRCodeView: QR image is fetched from the server at
    // runtime (network-dependent + requires AuthManager); a capture would show a
    // non-deterministic ProgressView spinner rather than a QR code.

    case "component.Kpi":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Kpi: missing state.component")
        }
        let kpiVariant: KpiVariant = {
            switch c.variant {
            case "compact": return .compact
            case "sparkline": return .sparkline
            case "iconValue": return .iconValue
            default: return .standard
            }
        }()
        let kpiValueType: KpiValueType = {
            switch c.valueType {
            case "currency": return .currency()
            case "percent": return .percent
            case "custom": return .custom(suffix: c.suffix ?? "")
            case "decimal": return .decimal()
            default: return .number
            }
        }()
        let kpiTrend: KpiTrend? = c.trend.map { KpiTrend(points: $0.points ?? []) }
        return AnyView(
            Kpi(
                value: c.kpiValue ?? 0,
                valueType: kpiValueType,
                label: c.label ?? "",
                description: c.description,
                icon: c.icon,
                iconColor: namedCaptureColor(c.iconColor),
                trend: kpiTrend,
                variant: kpiVariant
            )
            .padding(16)
        )
    case "component.MemberListItem":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.MemberListItem: missing state.component")
        }
        if c.variant == "contact" {
            let contact = MemberListContact(
                firstName: c.firstName ?? "",
                lastName: c.lastName ?? "",
                avatarURL: c.avatarUrl
            )
            return AnyView(MemberListItem(contact: contact).padding(16))
        }
        let memberVariant: MemberListItemVariant = {
            switch c.variant {
            case "member": return .member
            case "memberMultipleGroups": return .memberMultipleGroups
            default: return .memberWithInvite
            }
        }()
        // Member.age is derived from birthDate vs. now — subtract the fixture age
        // in years so the displayed age matches the fixture deterministically.
        let memberBirthDate = c.age.flatMap {
            Calendar.current.date(byAdding: .year, value: -$0, to: Date())
        }
        let member = Member(
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl,
            birthDate: memberBirthDate,
            joinDate: makeCaptureDateOptional(c.joinDate),
            groups: c.groups ?? []
        )
        return AnyView(MemberListItem(member: member, variant: memberVariant).padding(16))
    // SKIPPED component.ShareInviteSheet: full-page sheet that embeds
    // InviteQRCodeView (server-fetched QR), and requires AuthManager +
    // OverlayManager — the QR area renders as a non-deterministic spinner.

    case "component.WeekdayIndicator":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.WeekdayIndicator: missing state.component")
        }
        return AnyView(
            WeekdayIndicator(enabledDays: Set(c.enabledDays ?? []))
                .padding(16)
        )
    // ===== Input =====
    case "component.AgeRangeInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.AgeRangeInput: missing state.component") }
        return AnyView(
            FieldGroup {
                AgeRangeInput(
                    label: c.label ?? "Age range",
                    minAge: .constant(c.minAge ?? "0"),
                    maxAge: .constant(c.maxAge ?? "99")
                )
            }
            .padding(16)
        )
    case "component.BackgroundSourceMenu":
        return AnyView(
            BackgroundSourceMenu(
                onPickFromLibrary: {},
                onPickFromPhotos: {},
                onTakePhoto: {}
            )
            .padding(16)
        )
    case "component.BackgroundSwatch":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.BackgroundSwatch: missing state.component") }
        return AnyView(
            BackgroundSwatch(
                imageUrl: c.imageUrl,
                color: c.color,
                overlayOpacity: c.overlayOpacity,
                onTap: {}
            )
            .padding(16)
        )
    case "component.BlockStyleEditor":
        // The BlockStyleEditor adapter seeds a one-block READ activity into AppState
        // (via setupCaptureState); the editor reads its background/color/font state
        // from that block. We just need the ids + the title/theme init params.
        let bseActivityId = fixture.state?.activity?.id ?? ""
        let bseBlockId = fixture.state?.activity?.readBlocks?.first?.id ?? ""
        guard AppState.shared.activities[bseActivityId] != nil else {
            throw ViewRegistryError.unknownView("component.BlockStyleEditor: activity '\(bseActivityId)' not seeded")
        }
        let bseComponent = fixture.state?.component
        // Build TextThemes by decoding minimal JSON (TextTheme has no memberwise init).
        let bseThemes: [TextTheme]? = bseComponent?.availableThemes?.enumerated().compactMap { index, option in
            let dict: [String: Any] = [
                "id": "capture-theme-\(index)",
                "name": option.name ?? "Theme",
                "slug": "capture-theme-\(index)",
                "isSystem": false,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let theme = try? JSONDecoder().decode(TextTheme.self, from: data) else { return nil }
            return theme
        }
        return AnyView(
            BlockStyleEditor(
                activityId: bseActivityId,
                blockId: bseBlockId,
                blockTitle: bseComponent?.blockTitle,
                availableThemes: bseThemes
            )
            .environment(OverlayManager())
            .padding(16)
        )
    case "component.CoverImagePicker":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.CoverImagePicker: missing state.component") }
        let coverMode: CoverImagePickerMode = (c.mode == "display") ? .display : .editable
        return AnyView(
            CoverImagePicker(
                selectedImage: .constant(nil),
                programName: c.programName ?? "",
                programDescription: c.programDescription ?? "",
                mode: coverMode,
                existingImageUrl: c.existingImageUrl
            )
            .padding(16)
        )
    case "component.DatePickerField":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.DatePickerField: missing state.component") }
        return AnyView(
            FieldGroup {
                DatePickerField(
                    label: c.label ?? "Date",
                    date: .constant(makeCaptureDate(c.date?.string))
                )
            }
            .padding(16)
        )
    case "component.FieldGroup":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.FieldGroup: missing state.component") }
        let items = c.fieldRows ?? []
        return AnyView(
            FieldGroup {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Text(item)
                        .font(Typography.s17)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    if idx < items.count - 1 {
                        FieldGroupDivider()
                    }
                }
                if let desc = c.description {
                    FieldGroupDivider()
                    FieldGroupDescription(text: desc)
                }
            }
            .padding(16)
        )
    case "component.InlineFontSizePicker":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.InlineFontSizePicker: missing state.component") }
        return AnyView(
            InlineFontSizePicker(
                selectedSize: c.selectedSize ?? "m",
                onSizeSelected: { _ in }
            )
            .padding(16)
        )
    case "component.LargeTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LargeTextInput: missing state.component") }
        let largeInputType: InputType = {
            switch c.inputType {
            case "phone": return .phone
            case "integer": return .integer
            case "float": return .float
            case "currency": return .currency
            case "email": return .email
            case "percentage": return .percentage
            default: return .alphanumeric
            }
        }()
        return AnyView(
            FieldGroup {
                LargeTextInput(
                    label: c.label ?? "",
                    inputType: largeInputType,
                    text: .constant(c.text ?? "")
                )
                .padding(.horizontal, 16)
            }
            .padding(16)
        )
    case "component.MarkdownEditor":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MarkdownEditor: missing state.component") }
        return AnyView(
            MarkdownEditor(
                placeholder: c.placeholder ?? "",
                attributedText: .constant(MarkdownEditor.markdownToAttributed(c.markdown ?? "")),
                minHeight: 200,
                autoGrow: c.autoGrow ?? false
            )
            .padding(16)
        )
    case "component.MenuInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MenuInput: missing state.component") }
        let menuStyle: MenuInputStyle = {
            switch c.style {
            case "wheel": return .wheel
            case "inline": return .inline
            case "segmented": return .segmented
            default: return .menu
            }
        }()
        let menuInput: MenuInput = {
            if let described = c.optionsWithDescriptions {
                return MenuInput(
                    label: c.label ?? "",
                    options: described.map { MenuInputOption($0.value, description: $0.description) },
                    selectedOption: .constant(c.selectedOption ?? ""),
                    style: menuStyle
                )
            }
            return MenuInput(
                label: c.label ?? "",
                options: c.options?.strings ?? [],
                selectedOption: .constant(c.selectedOption ?? ""),
                style: menuStyle
            )
        }()
        return AnyView(
            FieldGroup { menuInput }
                .padding(16)
        )
    case "component.MultilineTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MultilineTextInput: missing state.component") }
        return AnyView(
            FieldGroup {
                MultilineTextInput(
                    placeholder: c.placeholder ?? "",
                    text: .constant(c.text ?? "")
                )
            }
            .padding(16)
        )
    case "component.RichTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.RichTextInput: missing state.component") }
        return AnyView(
            RichTextInput(
                placeholder: c.placeholder ?? "",
                html: .constant(c.html ?? ""),
                minHeight: 200,
                autoGrow: c.autoGrow ?? false,
                outputFormat: c.outputFormat ?? "html"
            )
            .padding(16)
        )
    case "component.SearchField":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.SearchField: missing state.component") }
        return AnyView(
            CaptureSearchFieldWrapper(
                isActive: c.isActive ?? false,
                searchText: c.searchText ?? "",
                placeholder: c.placeholder ?? "Search"
            )
            .padding(16)
        )
    case "component.TagInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TagInput: missing state.component") }
        return AnyView(
            TagInput(
                tags: .constant(c.tags ?? []),
                placeholder: c.placeholder ?? ""
            )
            .padding(16)
        )
    case "component.TextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TextInput: missing state.component") }
        let textInputType: InputType = {
            switch c.inputType {
            case "phone": return .phone
            case "integer": return .integer
            case "float": return .float
            case "currency": return .currency
            case "email": return .email
            case "percentage": return .percentage
            default: return .alphanumeric
            }
        }()
        let textInput: MakeReady.TextInput = {
            if let floating = c.floatingLabel {
                return MakeReady.TextInput(
                    floatingLabel: floating,
                    icon: c.icon,
                    inputType: textInputType,
                    text: .constant(c.text ?? "")
                )
            }
            if let label = c.label {
                return MakeReady.TextInput(
                    label: label,
                    icon: c.icon,
                    inputType: textInputType,
                    text: .constant(c.text ?? "")
                )
            }
            return MakeReady.TextInput(
                placeholder: c.placeholder ?? "",
                inputType: textInputType,
                text: .constant(c.text ?? "")
            )
        }()
        return AnyView(
            FieldGroup { textInput }
                .padding(16)
        )
    case "component.ToggleControl":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.ToggleControl: missing state.component") }
        return AnyView(
            ToggleGroup {
                ToggleControl(
                    title: c.title ?? "",
                    description: c.description ?? "",
                    isOn: .constant(c.isOn ?? false)
                )
            }
            .padding(16)
        )
    // ===== Navigation =====
    case "component.ActionCardMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.ActionCardMenu: missing state.component") }
        let actionItems: [ActionCardMenuItem] = (c.items ?? []).map { item in
            ActionCardMenuItem(
                icon: item.icon ?? "questionmark",
                title: item.title ?? "",
                description: item.description ?? ""
            ) {}
        }
        return AnyView(ActionCardMenu(title: c.title ?? "", items: actionItems).padding(16))
    default:
        return nil
    }
}

/// Part 4 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart4(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    // AddActivityMenu fills the screen (.frame(maxWidth/maxHeight: .infinity)) and fades in
    // from opacity 0 on .onAppear, so it can't be a .sizeThatFits component capture — render
    // it as a page (device layout) with animations disabled so the entrance fade resolves
    // instantly when onAppear flips `appeared`.
    case "pages.add-activity-menu":
        return AnyView(
            AddActivityMenu(
                overlayManager: OverlayManager(),
                existingActivityTypes: [],
                onActivitySelected: { _ in }
            )
            .transaction { $0.disablesAnimations = true }
        )
    case "pages.member-requests":
        // Seed AppState.pendingJoinRequestsByGroupId from fixture.state
        // .joinRequests; group names/order come from state.groups (already
        // seeded by CaptureEnvironment). Renders inside no chrome — the page
        // content itself (the ManagedPageView push is exercised live).
        if let seeds = fixture.state?.joinRequests {
            var byGroup: [String: [JoinRequest]] = [:]
            for seed in seeds {
                let request = JoinRequest(
                    id: seed.id,
                    status: "pending",
                    message: nil,
                    createdAt: Date(timeIntervalSince1970: seed.createdAt ?? 1_700_000_000),
                    member: JoinRequestMember(
                        id: seed.memberId ?? seed.id,
                        firstName: seed.firstName,
                        lastName: seed.lastName,
                        avatarUrl: nil
                    )
                )
                byGroup[seed.groupId, default: []].append(request)
            }
            AppState.shared.pendingJoinRequestsByGroupId = byGroup
        }
        return AnyView(
            MemberRequestsPage(overlayManager: OverlayManager(), onRequestApproved: {})
                .transaction { $0.disablesAnimations = true }
        )
    case "pages.member-profile":
        // MemberProfilePage loads its profile over the NETWORK (GroupActions,
        // not AppState), so the harness can only render the seeded pre-load
        // state: hero background + gradient + initials + name. The profile
        // fetch fails in the harness and may pop the error overlay — snapshot
        // renders the seed state; full-content variants are web-only.
        return AnyView(
            MemberProfilePage(
                memberId: fixture.state?.memberId ?? "capture-member",
                overlayManager: OverlayManager(),
                seedAvatarUrl: nil,
                seedName: fixture.state?.seedName ?? "Marcus Thompson"
            )
            .transaction { $0.disablesAnimations = true }
        )
    case "component.AddMenu":
        guard fixture.state?.component != nil else { throw ViewRegistryError.unknownView("component.AddMenu: missing state.component") }
        // AddMenu builds its rows from hardcoded content; the submenu sits offscreen at rest,
        // so both fixture variants render the main menu deterministically.
        return AnyView(
            AddMenu()
                .environment(OverlayManager())
                .environment(AuthManager())
                .padding(16)
        )
    case "component.FilterChipDropdown":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.FilterChipDropdown: missing state.component") }
        let chipItems: [FilterChipDropdownItem] = (c.items ?? []).map { item in
            FilterChipDropdownItem(id: item.id ?? UUID().uuidString, label: item.label ?? "")
        }
        let chipSelected = Set(c.selectedIds ?? [])
        return AnyView(
            FilterChipDropdownPanel(
                items: chipItems,
                selectedIds: chipSelected,
                showClearAll: c.showClearAll ?? true,
                onToggle: { _ in },
                onClearAll: {}
            )
            .padding(16)
        )
    case "component.HamburgerMenu":
        guard fixture.state?.component != nil else { throw ViewRegistryError.unknownView("component.HamburgerMenu: missing state.component") }
        // HamburgerMenu rows are hardcoded; fixture items are descriptive only.
        return AnyView(
            HamburgerMenu()
                .environment(OverlayManager())
                .padding(16)
        )
    case "component.InviteMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.InviteMenu: missing state.component") }
        // InviteMenu rows are hardcoded; menuId is the only fixture-driven value.
        return AnyView(
            InviteMenu(overlayManager: OverlayManager(), menuId: c.menuId ?? "preview")
                .environment(AuthManager())
                .padding(16)
        )
    case "component.LessonActionMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LessonActionMenu: missing state.component") }
        let lamSchedule = LessonSchedule(
            id: "capture-lesson-schedule",
            enrollmentId: c.enrollmentId ?? "e1",
            lessonId: "capture-lesson",
            scheduledDate: makeCaptureDate(c.scheduledDate),
            isCompleted: nil,
            completedAt: nil,
            lesson: LessonWithActivities(
                id: "capture-lesson",
                studyProgramId: "capture-program",
                dayNumber: c.dayNumber ?? 1,
                activities: []
            )
        )
        let lamMenu = LessonActionMenu(
            schedule: lamSchedule,
            studyName: c.studyName ?? "",
            enrollmentId: c.enrollmentId ?? "e1",
            onEditActivities: {},
            onOpenLesson: {},
            onShareLesson: {},
            onAddLesson: (c.showAddLesson ?? false) ? {} : nil,
            onEditEnrollment: (c.showEditEnrollment ?? false) ? {} : nil,
            onDelete: {}
        )
        return AnyView(
            lamMenu
                .environment(OverlayManager())
                .padding(16)
        )
    case "component.NavBar":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.NavBar: missing state.component") }
        let navTab: NavBarTab = {
            switch c.activeTab?.stringValue {
            case "home": return .home
            case "groups": return .groups
            case "library": return .library
            case "calendar": return .calendar
            case "search": return .search
            case "profile": return .profile
            default: return .none
            }
        }()
        return AnyView(NavBar(activeTab: navTab, avatarURL: c.avatarURL).padding(16))
    case "component.PageHeader":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.PageHeader: missing state.component") }
        return AnyView(
            MakeReady.PageHeader(tabs: c.tabs ?? [], activeTab: .constant(c.activeTab?.intValue ?? 0))
                .padding(16)
        )
    case "component.PageTitle":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.PageTitle: missing state.component") }
        let ptTitle = c.title ?? ""
        let ptView: AnyView = {
            switch c.factory {
            case "iconTitleLink":
                return AnyView(PageTitle.iconTitleLink(title: ptTitle, leftIcon: c.leftIcon, rightLink: c.rightLink ?? "Done", onLeftIconTap: {}, onRightLinkTap: {}))
            case "iconTitleIcon":
                return AnyView(PageTitle.iconTitleIcon(title: ptTitle, leftIcon: c.leftIcon ?? "xmark", rightIcon: c.rightIcon ?? "checkmark", onLeftIconTap: {}, onRightIconTap: {}))
            case "iconTitleIcons":
                let actions = (c.rightIcons ?? []).map { ic in
                    IconAction(icon: ic.icon ?? "questionmark", showBadge: ic.showBadge ?? false) {}
                }
                return AnyView(PageTitle.iconTitleIcons(title: ptTitle, leftIcon: c.leftIcon, rightIcons: actions, onLeftIconTap: {}))
            case "linkTitle":
                return AnyView(PageTitle.linkTitle(title: ptTitle, link: c.leftLink ?? "Done", onLinkTap: {}))
            case "linkTitleLink":
                return AnyView(PageTitle.linkTitleLink(title: ptTitle, leftLink: c.leftLink ?? "Cancel", rightLink: c.rightLink ?? "Save", onLeftLinkTap: {}, onRightLinkTap: {}))
            case "iconMenu":
                return AnyView(PageTitle.iconMenu(title: ptTitle, leftIcon: c.leftIcon ?? "xmark", onLeftIconTap: {}, onDropdownTap: {}))
            case "iconLink":
                return AnyView(PageTitle.iconLink(leftIcon: c.leftIcon ?? "xmark", rightLink: c.rightLink ?? "Done", onLeftIconTap: {}, onRightLinkTap: {}))
            case "iconIcon":
                return AnyView(PageTitle.iconIcon(leftIcon: c.leftIcon ?? "xmark", rightIcon: c.rightIcon ?? "checkmark", onLeftIconTap: {}, onRightIconTap: {}))
            case "icon":
                return AnyView(PageTitle.icon(icon: c.leftIcon ?? "xmark", onIconTap: {}))
            case "backLinkTitle":
                return AnyView(PageTitle.backLinkTitle(title: ptTitle, backText: c.backText ?? "", onBackTap: {}))
            case "titleOnly":
                return AnyView(PageTitle.titleOnly(title: ptTitle))
            default: // "iconTitle"
                return AnyView(PageTitle.iconTitle(title: ptTitle, icon: c.leftIcon, onIconTap: {}))
            }
        }()
        return AnyView(ptView.padding(16))
    case "component.TabSlider":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TabSlider: missing state.component") }
        return AnyView(
            TabSlider(tabs: c.tabs ?? [], selectedIndex: .constant(c.selectedIndex ?? 0))
                .padding(16)
        )
    case "component.UserMenu":
        // The UserMenu adapter projects the signed-in user into fixture.auth (→ the
        // mock authManager above) and the org list into component.organizations.
        // Seed those orgs into AppState so the per-org rows render.
        AppState.shared.userOrganizations = (fixture.state?.component?.organizations ?? []).map {
            OrganizationData(id: $0.id ?? "capture-org", name: $0.name ?? "Organization",
                             ownerId: nil, createdAt: nil, updatedAt: nil)
        }
        return AnyView(
            UserMenu()
                .environment(authManager)
                .environment(OverlayManager())
                .frame(width: 393)
                .padding(.vertical, 16)
                .background(Color.appBackground)
        )
    // ===== Chart =====
    // MARK: - Chart components
    //
    // Color strings in chart fixtures are hex ("#6c47ff") or rgba("rgba(...)").
    // Color(hex:) is reserved (Colors.swift only), so each case inlines a small
    // resolver mapping the known palette hexes to brand tokens and falling back
    // to a sensible default for rgba / unknown values.

    case "component.DonutChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.DonutChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.white.opacity(0.3)   // rgba / unknown → muted default
            }
        }
        let donutPoints: [DonutChartDataPoint] = (c.dataPoints ?? []).map {
            DonutChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            DonutChart(
                dataPoints: donutPoints,
                innerRadiusRatio: CGFloat(c.innerRadiusRatio ?? 0.75),
                showCenterLabel: c.showCenterLabel ?? true,
                centerLabelText: c.centerLabelText,
                centerLabelSubtext: c.centerLabelSubtext
            )
            .padding(16)
            .frame(height: 220)
        )
    case "component.HorizontalBarChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.HorizontalBarChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.brandPrimary.opacity(0.5)   // rgba shades / unknown → brand fade
            }
        }
        let hBarPoints: [BarChartDataPoint] = (c.dataPoints ?? []).map {
            BarChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            HorizontalBarChart(
                dataPoints: hBarPoints,
                showValues: c.showValues ?? true,
                barHeight: CGFloat(c.barHeight ?? 32)
            )
            .padding(16)
        )
    case "component.VerticalBarChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.VerticalBarChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.white.opacity(0.3)   // rgba / unknown → muted default
            }
        }
        let vBarPoints: [BarChartDataPoint] = (c.dataPoints ?? []).map {
            BarChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            VerticalBarChart(
                dataPoints: vBarPoints,
                showValues: c.showValues ?? true,
                chartHeight: CGFloat(c.chartHeight ?? 200)
            )
            .padding(16)
        )
    case "component.HeatMapChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.HeatMapChart: missing state.component") }
        let heatPoints: [HeatMapDataPoint] = (c.heatMapPoints ?? []).map {
            HeatMapDataPoint(week: $0.week ?? 0, day: $0.day ?? 0, value: $0.value ?? 0, dayLabel: $0.dayLabel ?? "")
        }
        // colorScale strings are hex/rgba; resolve last (most saturated) to a token
        // to drive the chart's continuous ramp, otherwise use the chart default.
        let scale: [Color]? = c.colorScale.map { raw in
            raw.map { s -> Color in
                switch s.lowercased() {
                case "#4ade80", "rgba(74,222,128,0.3)", "rgba(74,222,128,0.6)": return Color.green
                case "#ff6b9d", "rgba(255,107,157,0.3)", "rgba(255,107,157,0.6)": return Color.pink
                default: return Color.white.opacity(0.05)
                }
            }
        }
        return AnyView(
            HeatMapChart(
                dataPoints: heatPoints,
                colorScale: scale,
                showDayLabels: c.showDayLabels ?? true,
                chartHeight: CGFloat(c.chartHeight ?? 120)
            )
            .padding(16)
        )
    case "component.LineChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LineChart: missing state.component") }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let resolveHex: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.brandPrimary
            }
        }
        let trendLines: [TrendLine] = (c.trendLines ?? []).map { tl in
            let points: [ChartDataPoint] = (tl.dataPoints ?? []).map {
                ChartDataPoint(date: dateFormatter.date(from: $0.date ?? "") ?? Date(), value: $0.value ?? 0)
            }
            let chartColor: ChartColor
            if tl.color?.lowercased() == "gradient" {
                let colors = (tl.gradientColors ?? []).map { resolveHex($0) }
                chartColor = .gradient(colors: colors.isEmpty ? [Color.brandPrimary] : colors,
                                       angle: tl.gradientAngle ?? 90)
            } else {
                chartColor = .solid(resolveHex(tl.solidColor))
            }
            return TrendLine(dataPoints: points, color: chartColor, lineWidth: CGFloat(tl.lineWidth ?? 2))
        }
        let timeScale: TimeScale = {
            switch c.timeScale {
            case "hours": return .hours
            case "weeks": return .weeks
            case "months": return .months
            case "years": return .years
            default: return .days
            }
        }()
        let interp: ChartInterpolationMethod = {
            switch c.interpolationMethod {
            case "linear": return .linear
            case "catmullRom": return .catmullRom
            default: return .monotone
            }
        }()
        return AnyView(
            LineChart(
                trendLines: trendLines,
                timeScale: timeScale,
                yAxisScale: .auto,
                interactive: c.interactive ?? true,
                animated: c.animated ?? true,
                showArea: c.showArea ?? false,
                interpolationMethod: interp
            )
            .padding(16)
        )
    // ===== CalContentLoading =====
    // MARK: - Calendar

    case "component.CalendarBottomBar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarBottomBar: missing state.component")
        }
        // `showViewModes` decides whether the view-mode toggles (and divider) appear:
        // they only render when an `onViewModeChange` closure is supplied. The bar's
        // internal `selectedMode` defaults to `.month`, matching the fixture.
        let calBottomBar: CalendarBottomBar = {
            if c.showViewModes == true {
                return CalendarBottomBar(onTodayTap: {}, onViewModeChange: { _ in })
            }
            return CalendarBottomBar(onTodayTap: {})
        }()
        return AnyView(calBottomBar.padding(16))
    case "component.CalendarDayCell":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarDayCell: missing state.component")
        }
        // UIKit UICollectionViewCell — wrap in UIViewPreviewWrapper (defined alongside
        // the cell). `isToday` is computed from the day's date via Calendar, so the
        // "today" case uses Date(); other cases use a fixed past date for determinism.
        let dayCellEvents: [SplitCalendarEvent] = (c.eventColors ?? []).enumerated().map { idx, hex in
            SplitCalendarEvent(
                id: "capture-daycell-event-\(idx)",
                title: "Event \(idx + 1)",
                startTime: Date(timeIntervalSince1970: 1_769_000_000),
                color: hex
            )
        }
        let dayCellDate: Date = (c.isToday == true)
            ? Date()
            : Date(timeIntervalSince1970: 1_769_000_000)
        let splitDay = SplitCalendarDay(
            date: dayCellDate,
            dayNumber: c.dayNumber ?? 1,
            isCurrentMonth: c.isCurrentMonth ?? true,
            weekdayIndex: 0,
            rowIndex: 0,
            events: dayCellEvents
        )
        let dayCell = CalendarDayCell(frame: CGRect(x: 0, y: 0, width: 48, height: 56))
        dayCell.configure(with: splitDay, isSelected: c.isSelected ?? false)
        dayCell.backgroundColor = UIColor(Color.appBackground)
        return AnyView(
            UIViewPreviewWrapper(view: dayCell)
                .frame(width: 48, height: 56)
                .padding(16)
        )
    case "component.CalendarEventListContent":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarEventListContent: missing state.component")
        }
        let eventListEvents: [SplitCalendarEvent] = (c.events ?? []).map { e in
            SplitCalendarEvent(
                id: e.id,
                title: e.title ?? "",
                subtitle: e.subtitle,
                startTime: Date(timeIntervalSince1970: 1_769_000_000),
                color: e.color ?? "#6c47ff",
                dayNumber: e.dayNumber,
                coverImageUrl: e.coverImageUrl,
                activityIcons: (e.activityIcons ?? []).map {
                    CalendarActivityIcon(icon: $0.icon ?? "circle.fill", label: $0.label ?? "")
                }
            )
        }
        return AnyView(
            CalendarEventListContent(
                events: eventListEvents,
                selectedDate: makeCaptureDate(c.selectedDate),
                onEventTap: { _ in }
            )
        )
    case "component.CalendarWeekdayHeader":
        // No props — renders the fixed "S M T W T F S" header row.
        return AnyView(CalendarWeekdayHeader())
    // SKIPPED component.SplitMonthCalendar: UIViewControllerRepresentable wrapping a
    // live SplitMonthCalendarController (UICollectionView + scroll/expand/snapshot
    // pipeline). It cannot render meaningfully under .sizeThatFits without a hosting
    // window and a driven controller.

    // MARK: - Content

    // SKIPPED component.BibleVerseTextLayout: this is a static-helper enum
    // (fonts/insets/attributed-text builders), not a standalone View. Rendering it
    // would require reimplementing the reader's UITextView/badge layout pipeline.

    case "component.ExegesisVerseView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ExegesisVerseView: missing state.component")
        }
        let exegesisHighlights: [ReadBlockSelection] = (c.highlights ?? []).map {
            ReadBlockSelection(start: $0.start, end: $0.end, style: $0.style ?? "highlight")
        }
        return AnyView(
            ExegesisVerseView(
                plainText: c.plainText ?? "",
                highlights: exegesisHighlights,
                isSelectionEnabled: c.isSelectionEnabled ?? false,
                fontSize: CGFloat(c.fontSize ?? 16),
                usePreviewHighlightStyle: c.usePreviewHighlightStyle ?? false,
                pendingRange: .constant(nil),
                // 6.8 / 09 §G-ac — this surface's capture path runs `.verseTap`,
                // which is the mode that paints a seeded live span.
                initialLiveSelection: c.liveSelection.map {
                    NSRange(location: $0.start, length: max(0, $0.end - $0.start))
                }
            )
            .padding(16)
        )
    case "component.SelectableLockedBlockView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SelectableLockedBlockView: missing state.component")
        }
        let lockedSelections: [ReadBlockSelection] = (c.selections ?? []).map {
            ReadBlockSelection(start: $0.start, end: $0.end, style: $0.style ?? "highlight")
        }
        return AnyView(
            SelectableLockedBlockView(
                plainText: c.plainText ?? "",
                selections: lockedSelections,
                isSelectionEnabled: c.isSelectionEnabled ?? false,
                editingRange: nil,
                pendingRange: .constant(nil),
                // Seedable since 6.8 so the live `@0.55` wash is capturable at
                // all; `.constant` is right here — a snapshot never mutates it.
                liveSelection: .constant(c.liveSelection.map {
                    NSRange(location: $0.start, length: max(0, $0.end - $0.start))
                }),
                fontSize: CGFloat(c.fontSize ?? 16),
                usePreviewHighlightStyle: c.usePreviewHighlightStyle ?? false,
                isScripture: c.isScripture ?? true
            )
            .padding(16)
        )
    // SKIPPED component.ThemedContentView: WKWebView that loads a bundled
    // `themed-content.html` and renders via injected JS (window.renderTheme). Web
    // content loads asynchronously, so it produces nothing under a synchronous
    // .sizeThatFits capture.

    // MARK: - Loading

    case "component.CardSpinnerOverlay":
        // No props — a dimming spinner overlay. Render over a card-sized frame so
        // the overlay has bounds to fill (it has no intrinsic size of its own).
        return AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cardBackground)
                CardSpinnerOverlay()
            }
            .frame(width: 320, height: 140)
            .padding(16)
        )
    default:
        return nil
    }
}

/// Part 5 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart5(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ShimmerView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ShimmerView: missing state.component")
        }
        // ShimmerView ships as a `.shimmer()` modifier, not a view. Build the
        // skeleton shape(s) the fixture describes and apply the modifier.
        let shimmerContent: AnyView = {
            if c.shape == "textRows" {
                return AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array((c.rows ?? []).enumerated()), id: \.offset) { _, row in
                            RoundedRectangle(cornerRadius: CGFloat(row.cornerRadius ?? 4))
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: CGFloat(row.width ?? 120), height: CGFloat(row.height ?? 20))
                        }
                    }
                    .shimmer()
                )
            }
            return AnyView(
                RoundedRectangle(cornerRadius: CGFloat(c.cornerRadius ?? 8))
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: CGFloat(c.width ?? 320), height: CGFloat(c.height ?? 100))
                    .shimmer()
            )
        }()
        return AnyView(shimmerContent.padding(16))
    // ===== CardsEtc =====
    // MARK: - Cards (Components/Card/)

    case "component.CardGroupMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardGroupMini: missing state.component")
        }
        let cgmImageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: c.iconSystemName ?? "person.2.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let cgmData = CardGroupData(
            id: "capture-card-group-mini",
            title: c.title ?? "",
            imageStyle: cgmImageStyle,
            metadata: makeCaptureDataItems(c.metadata),
            isSelected: c.selected?.boolValue ?? false
        )
        return AnyView(CardGroupMini(data: cgmData).padding(16))
    case "component.SkeletonCardGroup":
        return AnyView(SkeletonCardGroup().padding(16))
    case "component.SkeletonCardLesson":
        return AnyView(SkeletonCardLesson().padding(16))
    case "component.SkeletonCardLessonActivity":
        return AnyView(SkeletonCardLessonActivity().padding(16))
    case "component.SkeletonCardMediaFull":
        return AnyView(SkeletonCardMediaFull().frame(width: 120).padding(16))
    case "component.SkeletonCardProgramFull":
        return AnyView(SkeletonCardProgramFull().padding(16))
    case "component.SkeletonCardStudy":
        return AnyView(SkeletonCardStudy().padding(16))
    case "component.SlideButton":
        // SlideButton is a data struct, not a View. Its visual is the circular
        // action button rendered inside SwipeableCard.buttonRow. Reproduce that
        // pill (48×48 circle + white icon) so the button can be compared standalone.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SlideButton: missing state.component")
        }
        let slideBackground: Color = {
            switch c.style {
            case "reschedule": return Color.accentBlue
            case "delete": return Color.destructive
            default: return Color.white.opacity(0.2)   // skip | edit
            }
        }()
        return AnyView(
            Image(systemName: c.icon ?? "questionmark")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(slideBackground)
                .clipShape(Circle())
                .padding(16)
        )
    case "component.SwipeableCard":
        // SwipeableCard wraps content and only reveals its action buttons once
        // swiped (abs(offset) > 5). At rest it shows just the content, so render
        // it around a simple placeholder card.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SwipeableCard: missing state.component")
        }
        let swipeButtons: [SlideButton] = (c.slideButtons ?? []).map { b in
            let style: SlideButtonStyle = {
                switch b.style {
                case "reschedule": return .reschedule
                case "delete": return .delete
                case "edit": return .edit
                default: return .skip
                }
            }()
            return SlideButton(icon: b.icon ?? "circle", style: style, action: {})
        }
        return AnyView(
            SwipeableCard(
                slideButtons: swipeButtons,
                isSwipeEnabled: c.isSwipeEnabled ?? true,
                onTap: {}
            ) {
                CardGroupMini(data: CardGroupData(
                    id: "capture-swipeable-content",
                    title: "Swipeable Card",
                    imageStyle: .icon(systemName: "person.2.fill", backgroundColor: nil, foregroundColor: nil),
                    metadata: [DataItem(number: "12", label: "Members")],
                    isSelected: false
                ))
            }
            .padding(16)
        )
    // MARK: - Domain (Components/Domain/)

    case "component.SkeletonEnrollmentCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SkeletonEnrollmentCard: missing state.component")
        }
        return AnyView(
            SkeletonEnrollmentCard(
                programName: c.programName ?? "",
                programImageUrl: c.programImageUrl,
                programDays: c.programDays ?? 0
            ).padding(16)
        )
    // MARK: - Group (Components/Group/)

    case "component.GroupActionButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupActionButton: missing state.component")
        }
        return AnyView(
            GroupActionButton(
                label: c.label ?? "",
                icon: c.icon ?? "circle",
                action: {}
            ).padding(16)
        )
    case "component.SkeletonPostCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SkeletonPostCard: missing state.component")
        }
        if let name = c.programName {
            return AnyView(SkeletonPostCard(programName: name, programImageUrl: c.programImageUrl).padding(16))
        }
        return AnyView(SkeletonPostCard().padding(16))
    // MARK: - Feedback (Components/Feedback/)

    case "component.ConfirmationOverlay":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ConfirmationOverlay: missing state.component")
        }
        let confStyle: ConfirmationOverlayStyle = {
            switch c.style {
            case "error": return .error
            case "warning": return .warning
            case "info": return .info
            default: return .success
            }
        }()
        return AnyView(
            ConfirmationOverlay(
                style: confStyle,
                message: AttributedString.safeMarkdown(c.message ?? ""),
                buttonLabel: c.buttonLabel ?? "OK",
                isProcessing: .constant(c.isProcessing ?? false),
                processingMessage: c.processingMessage ?? "Processing...",
                onDismiss: {}
            )
        )
    case "component.ErrorBanner":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ErrorBanner: missing state.component")
        }
        return AnyView(
            ErrorBanner(
                message: c.message ?? "",
                onRetry: (c.hasRetry ?? false) ? {} : nil,
                onDismiss: {}
            )
        )
    case "component.UnenrollConfirmation":
        // UnenrollConfirmation is a namespace of static helpers that presents a
        // ConfirmationOverlay (style .warning, "Done" button) via OverlayManager.
        // Render that resulting overlay directly using its successMessage builder.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.UnenrollConfirmation: missing state.component")
        }
        let unenrollOption: UnenrollOption = (c.option == "cancelFuture") ? .cancelFuture : .fullRemoval
        return AnyView(
            ConfirmationOverlay(
                style: .warning,
                message: UnenrollConfirmation.successMessage(
                    option: unenrollOption,
                    programName: c.programName ?? ""
                ),
                buttonLabel: "Done",
                isProcessing: .constant(c.isProcessing ?? false),
                processingMessage: "Processing unenrollment",
                onDismiss: {}
            )
        )
    // ===== LayoutOverlayVideo =====
    // MARK: - Layout / Overlays / Video
    //
    // Paste these cases INSIDE the `switch fixture.view` in ViewRegistry.swift.
    // They depend on three new CaptureComponent fields + two new sub-structs —
    // see LayoutOverlayVideo.fields.txt.

    case "component.SearchableList":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SearchableList: missing state.component")
        }
        // Build literal Identifiable & Hashable items from the fixture.
        struct CaptureSearchRow: Identifiable, Hashable {
            let id = UUID()
            let name: String
            let hasPhone: Bool
        }
        let searchRows: [CaptureSearchRow] = (c.searchItems ?? []).map {
            CaptureSearchRow(name: $0.name ?? "", hasPhone: $0.hasPhone ?? false)
        }
        // GeometryReader/ZStack-based — fill-space, so give it an explicit height.
        return AnyView(
            SearchableList(
                items: searchRows,
                filterPredicate: { (row: CaptureSearchRow, query: String) in
                    row.name.lowercased().contains(query.lowercased())
                },
                placeholder: c.placeholder ?? "Search",
                showAlphabetScrubber: c.showAlphabetScrubber ?? false,
                sectionKeyPath: (c.showAlphabetScrubber ?? false) ? \CaptureSearchRow.name : nil,
                autoFocusSearch: false
            ) { (row: CaptureSearchRow) in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                    Spacer()
                    if row.hasPhone {
                        Text("Invite")
                            .font(Typography.s12)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(height: 640)
        )
    case "component.SectionedTableView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SectionedTableView: missing state.component")
        }
        // UIViewControllerRepresentable (UITableViewController) — renders standalone
        // with literal data; fill-space so give it an explicit height.
        struct CaptureTableRow: Identifiable, Hashable {
            let id = UUID()
            let name: String
        }
        let tableSections: [(String, [CaptureTableRow])] = (c.tableSections ?? []).map { sec in
            (sec.title ?? "", (sec.items ?? []).map { CaptureTableRow(name: $0.name ?? "") })
        }
        return AnyView(
            SectionedTableView(
                sections: tableSections,
                sectionIndexTitles: tableSections.map { $0.0 },
                topInset: 16
            ) { (row: CaptureTableRow) in
                HStack {
                    Text(row.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(16)
            }
            .frame(height: 480)
            .padding(16)
        )
    case "component.StylePickerMenu":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.StylePickerMenu: missing state.component")
        }
        // Pure SwiftUI menu content. currentStyle from c.style ("bold" | "highlight" | nil).
        let pickerStyle: ReadBlockSelectionStyle? = {
            switch c.style {
            case "bold": return .bold
            case "highlight": return .highlight
            default: return nil
            }
        }()
        return AnyView(
            StylePickerMenu(
                snippet: c.text ?? "",
                currentStyle: pickerStyle,
                onSelect: { _ in }
            )
            .padding(.vertical, 16)
        )
    case "component.VideoGridItem":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.VideoGridItem: missing state.component")
        }
        // .video(VideoAsset) requires a real PHAsset (no way to fabricate in tests).
        // Only the .camera case stands alone.
        guard c.type != "video" else {
            // SKIPPED component.VideoGridItem (Video variant): .video(VideoAsset)
            // needs a live PhotoKit PHAsset; cannot construct one in a unit test.
            throw ViewRegistryError.unknownView("component.VideoGridItem: video variant needs a live PHAsset (PhotoKit) — skipped")
        }
        return AnyView(
            VideoGridItem(
                type: .camera,
                isSelected: c.isSelected ?? false,
                size: CGFloat(c.sizePx ?? 100),
                onTap: {}
            )
            .padding(16)
        )
    case "component.VideoPreview":
        // SelectedAsset/recordedVideoURL both require live media (PHAsset / AVAsset);
        // there's no hook to inject a UIImage thumbnail. Render the empty-placeholder
        // chrome (both nil) at a fixed frame — represents the "Select a video" state.
        return AnyView(
            VideoPreview(
                selectedAsset: nil,
                recordedVideoURL: nil,
                onTap: {}
            )
            .frame(width: 330, height: 440)
            .padding(16)
        )
    case "component.VideoSourceBar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.VideoSourceBar: missing state.component")
        }
        let videoSource: VideoSource = {
            switch c.currentSource {
            case "favorites": return .favorites
            case "makeReady": return .makeReady
            case "allAlbums": return .allAlbums
            default: return .videos
            }
        }()
        return AnyView(
            VideoSourceBar(
                currentSource: .constant(videoSource),
                onSourceTap: {},
                onMakeReadyTap: {}
            )
            .padding(.vertical, 16)
        )
    // ── UI 2.0 preview builds (docs/ui2/preview-build.md) ──
    case "component.ui2.C-045":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-045: missing state.component")
        }
        // C-045 §4 gives no default for `placeholder`, `kind` or `focused`, so a nil is a
        // fixture bug, not a value to guess. `text` defaults to "" — §4's own "empty →
        // placeholder shows"; `alignment` (.leading) and `countryCode` ("+1") are §4 defaults.
        guard let placeholder = c.placeholder else {
            throw ViewRegistryError.unknownView("component.ui2.C-045: missing props.placeholder")
        }
        guard let kindRaw = c.kind, let kind = UI2Preview.TextInput.Kind(rawValue: kindRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-045: props.kind must be single|multi|phone")
        }
        guard let focused = c.focused else {
            throw ViewRegistryError.unknownView("component.ui2.C-045: missing props.focused")
        }
        let ui2C045Alignment: UI2Preview.TextInput.Alignment
        if let alignmentRaw = c.alignment {
            guard let parsed = UI2Preview.TextInput.Alignment(rawValue: alignmentRaw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-045: props.alignment must be leading|center")
            }
            ui2C045Alignment = parsed
        } else {
            ui2C045Alignment = .leading
        }
        return declareCase(
            UI2Preview.TextInput(
                text: c.text ?? "",
                placeholder: placeholder,
                kind: kind,
                alignment: ui2C045Alignment,
                focused: focused,
                countryCode: c.countryCode ?? "+1"
            ),
            PreviewFrame(width: 387)  // OQ-PB-1 default: C-045 §1 deviation 2 master width
        )
    case "component.ui2.C-040":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-040: missing state.component")
        }
        // C-040 §4: `style` and `rightButtons` are required, so a nil is a fixture bug, not a
        // value to guess. `title` is `String?` outright. Every other prop has a §4 default:
        // showTitle / showIcons true, leadingGlyph back, leadingLabel "Cancel", trailingLabel "Done",
        // trailingEnabled true.
        guard let styleRaw = c.style else {
            throw ViewRegistryError.unknownView("component.ui2.C-040: missing props.style")
        }
        let ui2C040Style: UI2Preview.PageHeader.Style
        switch styleRaw {
        case "default": ui2C040Style = .default
        case "textButtons": ui2C040Style = .textButtons
        case "twoIcons": ui2C040Style = .twoIcons
        case "backAndLink": ui2C040Style = .backAndLink
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-040: props.style must be default|textButtons|twoIcons|backAndLink"
            )
        }
        guard let ui2C040RightRaw = c.rightButtons else {
            throw ViewRegistryError.unknownView("component.ui2.C-040: missing props.rightButtons")
        }
        // An unknown glyph name is a fixture bug, not a value to guess.
        let ui2C040Leading: UI2Preview.GlyphButton.Glyph
        if let raw = c.leadingGlyph {
            guard let parsed = UI2Preview.GlyphButton.Glyph(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-040: props.leadingGlyph \"\(raw)\" is not a C-021 glyph")
            }
            ui2C040Leading = parsed
        } else {
            ui2C040Leading = .back                     // §4 default
        }
        let ui2C040Right: [UI2Preview.GlyphButton.Glyph] = try ui2C040RightRaw.map { raw in
            guard let parsed = UI2Preview.GlyphButton.Glyph(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-040: props.rightButtons \"\(raw)\" is not a C-021 glyph")
            }
            return parsed
        }
        let ui2C040Header = UI2Preview.PageHeader(
            style: ui2C040Style,
            title: c.title,
            showTitle: c.showTitle ?? true,
            showIcons: c.showIcons ?? true,
            leadingGlyph: ui2C040Leading,
            rightButtons: ui2C040Right,
            leadingLabel: c.leadingLabel ?? "Cancel",
            trailingLabel: c.trailingLabel ?? "Done",
            trailingEnabled: c.trailingEnabled ?? true
        )
        // The master width and specimen margin are the PREVIEW's frame. A fill capture (designer-pick-width)
        // and a design capture draw the bare header at the page width — the runner's rule (designer-live-picks D5).
        return declareCase(ui2C040Header, PreviewFrame(width: 398))  // C-040 §1: each symbol 398×56
    case "component.ui2.C-024":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-024: missing state.component")
        }
        // C-024 §4 gives a default only for `targetBars` (nil = one bar per point) and
        // `averageLabel` (nil = line only), so those two read straight through. `series`,
        // `align`, `widthFill` and `showAverage` have no contract default — a nil is a fixture
        // bug, not a value to guess. `averageLabelSide` is only meaningful with a label.
        guard let series = c.series else {
            throw ViewRegistryError.unknownView("component.ui2.C-024: missing props.series")
        }
        guard let alignRaw = c.align, let align = UI2Preview.SparkBarChart.Align(rawValue: alignRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-024: props.align must be top|center|bottom")
        }
        guard let fillRaw = c.widthFill, let widthFill = UI2Preview.SparkBarChart.WidthFill(rawValue: fillRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-024: props.widthFill must be bars|gaps")
        }
        guard let showAverage = c.showAverage else {
            throw ViewRegistryError.unknownView("component.ui2.C-024: missing props.showAverage")
        }
        let ui2C024LabelSide: UI2Preview.SparkBarChart.LabelSide
        switch c.averageLabelSide {
        case "left": ui2C024LabelSide = .left
        case "right", nil: ui2C024LabelSide = .right   // §4: right is the designed placement
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-024: props.averageLabelSide must be left|right")
        }
        return declareCase(
            UI2Preview.SparkBarChart(
                series: series,
                targetBars: c.targetBars,
                align: align,
                widthFill: widthFill,
                showAverage: showAverage,
                averageLabel: c.averageLabel,
                averageLabelSide: ui2C024LabelSide
            ),
            // OQ-PB-1: C-024 states no master width — §4 Sizing is explicit that the component
            // has NO intrinsic size and fills its container, so the call site must fix BOTH
            // axes. 97×64 is §2's stated sample footprint, i.e. the frozen snapshot's own
            // symbol size, which is what makes the render and the snapshot comparable.
            PreviewFrame(width: 97, height: 64)
        )
    default:
        return nil
    }
}

/// Part 6 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart6(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ui2.C-021":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-021: missing state.component")
        }
        // C-021 §4 gives no default for `glyph` — it is the whole of the component, so a
        // nil or an unknown name is a fixture bug, not a value to guess. `action` (spelled
        // `onTap` by R-33) is interaction-bearing and defaulted to a no-op in the view.
        guard let glyphRaw = c.glyph, let glyph = UI2Preview.GlyphButton.Glyph(rawValue: glyphRaw) else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-021: props.glyph must be one of C-021 §3's nine glyph names"
            )
        }
        return declareCase(
            UI2Preview.GlyphButton(glyph: glyph),
            // No master width to pin: the component hugs its 24pt glyph (its 44pt tap area is
            // a content shape, OQ-C-021-001), so the call site adds only the page margin and
            // the ground the snapshot is framed on.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-026":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-026: missing state.component")
        }
        // C-026 §4 gives no default for `days` or `window` — they are the whole of the chart,
        // so a nil is a fixture bug, not a value to guess. `onPan` is interaction-bearing and
        // defaulted to a no-op in the view (OQ-PB-3). `today` is the capture seam: §3 derives
        // `state` from whether today falls inside the window, and reading the real clock would
        // make the render change state on its own — see UI2Preview/DualSeriesBarChart.swift.
        guard let timeline = c.days?.timeline else {
            throw ViewRegistryError.unknownView("component.ui2.C-026: missing props.days (day timeline)")
        }
        guard let windowSpec = c.window,
              let windowStart = makeUI2ChartDate(windowSpec.start),
              let windowEnd = makeUI2ChartDate(windowSpec.end),
              windowStart <= windowEnd else {
            throw ViewRegistryError.unknownView("component.ui2.C-026: props.window must be { start, end } as yyyy-MM-dd, start ≤ end")
        }
        guard let today = makeUI2ChartDate(c.today?.stringValue) else {
            throw ViewRegistryError.unknownView("component.ui2.C-026: missing props.today (yyyy-MM-dd)")
        }
        let ui2C026Days: [UI2Preview.DualSeriesBarChart.Day] = try timeline.map {
            guard let date = makeUI2ChartDate($0.date) else {
                throw ViewRegistryError.unknownView("component.ui2.C-026: props.days[].date \"\($0.date)\" is not yyyy-MM-dd")
            }
            return UI2Preview.DualSeriesBarChart.Day(
                date: date, scheduled: $0.scheduled, completed: $0.completed
            )
        }
        return AnyView(
            UI2Preview.DualSeriesBarChart(
                days: ui2C026Days,
                window: windowStart...windowEnd,
                today: today
            )
            // OQ-PB-1: C-026 §2 states a FIXED 440×149 footprint, so both axes are pinned here.
            // 440pt is exactly the iPhone 16 Pro Max logical width the runner renders at, which
            // is why this call site adds NO page margin — §2's "full-bleed within
            // `space-page-margin` insets on consumers" describes the consumer's inset, and
            // applying it here would squeeze the chart to 408 and invalidate every x in §2.
            .frame(width: 440, height: 149)
            .frame(maxWidth: .infinity)
            .background(UI2Preview.Token.layoutBackground)  // OQ-PB-2 default
        )
    case "component.ui2.C-034":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-034: missing state.component")
        }
        // C-034 §4 gives no default for `placeholder` (§1 deviation 1: every consumer sets its
        // own) or `focused`, so a nil in either is a fixture bug. `text` defaults to empty —
        // §4: "empty → placeholder shows" — which is the contract's own default, not a guess.
        // `onChange`/`onClear` are interaction-bearing and no-ops in the view (OQ-PB-3).
        guard let placeholder = c.placeholder else {
            throw ViewRegistryError.unknownView("component.ui2.C-034: missing props.placeholder")
        }
        guard let focused = c.focused else {
            throw ViewRegistryError.unknownView("component.ui2.C-034: missing props.focused")
        }
        // OQ-PB-1 default: the contract's master width. §1 deviation 2 — "Master symbols are 387pt wide;
        // consumers are width-driven." 387 is the preview's frame; a bare capture fills the width it is offered.
        return declareCase(
            UI2Preview.SearchField(
                text: c.text ?? "",
                placeholder: placeholder,
                focused: focused,
                showsClearWhenEmpty: c.showsClearWhenEmpty ?? false   // §4 default `false`
            ),
            PreviewFrame(width: 387)
        )
    case "component.ui2.C-029":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-029: missing state.component")
        }
        // C-029 §4 gives no default for any of the four props — `hourValues` is the whole of the
        // ring and the centre trio is the whole of the key value — so a nil is a fixture bug,
        // not a value to guess. C-029 has no interaction-bearing props at all (§3: "display-only;
        // the chart itself has no interactivity"), so OQ-PB-3 does not arise here.
        guard let hourValues = c.hourValues, hourValues.count == 24 else {
            throw ViewRegistryError.unknownView("component.ui2.C-029: props.hourValues must be 24 numbers")
        }
        guard let centerValue = c.centerValue,
              let centerUnit = c.centerUnit,
              let centerCaption = c.centerCaption else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-029: missing props.centerValue / centerUnit / centerCaption"
            )
        }
        return declareCase(
            UI2Preview.RadialDayClock(
                hourValues: hourValues,
                centerValue: centerValue,
                centerUnit: centerUnit,
                centerCaption: centerCaption
            ),
            // OQ-PB-1 default: C-029 §2 states a fixed 357×326 footprint, so both axes are
            // pinned here. §2 also says "labels overhang the frame's layout box on all four
            // sides", so the page margin below is doing real work — without it the 12 AM and
            // 12 PM labels would sit on the image edge, exactly as they do in the frozen
            // snapshot's own 374×334 export.
            PreviewFrame(width: 357, height: 326, intrinsic: true)
        )
    case "component.ui2.C-030":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-030: missing state.component")
        }
        // C-030 §4 gives no default for either prop — `bins` is the whole of the chart and
        // `tickLabels` the whole of the tick row — so a nil is a fixture bug, not a value to
        // guess. §4 states "No pan/interaction props", so OQ-PB-3 does not arise here.
        guard let bins = c.bins, !bins.isEmpty else {
            throw ViewRegistryError.unknownView("component.ui2.C-030: missing props.bins")
        }
        guard let tickLabels = c.tickLabels else {
            throw ViewRegistryError.unknownView("component.ui2.C-030: missing props.tickLabels")
        }
        return declareCase(
            UI2Preview.TimeActivityChart(
                bins: bins,
                // Back to §4's tuple type; CaptureUI2TickLabel exists only because a tuple is
                // not Codable (see CaptureFixture.swift).
                tickLabels: tickLabels.map { (value: $0.value, unit: $0.unit) }
            ),
            // OQ-PB-1 default: C-030 §2 states a fixed 438×140 footprint (chart 100 + gap 16 +
            // tick row 24), so both axes are pinned here. 438 is wider than the 408 a page-margin
            // inset would leave on a 440pt Pro Max, so this call site adds NO horizontal margin —
            // squeezing the chart would invalidate §2's 5px pitch and its 88-bar count.
            PreviewFrame(width: 438, height: 140, marginEdges: .vertical, intrinsic: true)
        )
    case "component.ui2.C-019":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-019: missing state.component")
        }
        // C-019 §3 is a MIXED state matrix: two rows belong to the C-019 row and four to
        // C-069 NavTabButton, whose contract is C-019 §2b and which has no contract file —
        // and therefore no comparison row — of its own. So both units render through this
        // one case, dispatched on `presentation`, which is C-069's prop alone.
        //
        // C-069 now has a contract and a case of its own (component.ui2.C-069, `expansion` 0…1 +
        // `hasAdd`); these legacy C-019 previews map their old props onto it — `presentation` →
        // the designed endpoint, `addAction` presence → `hasAdd`.
        if let presentationRaw = c.presentation {
            guard presentationRaw == "collapsed" || presentationRaw == "expanded" else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-019: props.presentation must be collapsed|expanded"
                )
            }
            // §4 (C-069) gives no default for `label` or `active`, so a nil is a fixture bug,
            // not a value to guess. `addAction` is optional by contract — absent means the
            // card renders no add slot, which is exactly §2b's collapsed case.
            guard let label = c.label else {
                throw ViewRegistryError.unknownView("component.ui2.C-019: missing props.label")
            }
            guard let active = c.active else {
                throw ViewRegistryError.unknownView("component.ui2.C-019: missing props.active")
            }
            return declareCase(
                UI2Preview.NavTabButton(
                    label: label,
                    expansion: presentationRaw == "expanded" ? 1 : 0,
                    active: active,
                    hasAdd: c.addAction ?? false
                ),
                PreviewFrame(alignment: .leading, intrinsic: true)  // §2b sizes itself; sit leading
            )
        }
        // §4 (C-019) gives no default for `tabs`, `selectedTab` or `expansion`; `scrollOffset`
        // is 0 at both designed resting states (§3 designs no scrolled one — the scrolled
        // positions live only in the evidence-only instance frame), so 0 is the contract's
        // value here, not a guess.
        guard let tabs = c.tabs else {
            throw ViewRegistryError.unknownView("component.ui2.C-019: missing props.tabs")
        }
        guard let selectedTab = c.selectedTab else {
            throw ViewRegistryError.unknownView("component.ui2.C-019: missing props.selectedTab")
        }
        guard let expansion = c.expansion else {
            throw ViewRegistryError.unknownView("component.ui2.C-019: missing props.expansion")
        }
        return declareCase(
            UI2Preview.TopNav(
                tabs: tabs,
                selectedTab: selectedTab,
                expansion: expansion,
                scrollOffset: c.scrollOffset ?? 0
            ),
            // OQ-PB-1 has no master width to take here: §2's content is 656 (collapsed) /
            // 1048 (expanded), both wider than the 440pt device, and §2 says the row "clips
            // at the raw edges — no fade mask". So the row is given the DEVICE width and
            // clips, which IS the design; framing it at 656/1048 would only overflow the
            // capture. 440 is pinned rather than `maxWidth: .infinity` because the harness
            // proposes an unconstrained width, against which `.infinity` resolves to the
            // row's own 656/1048 and the clip never happens — §2's own "the 440pt device".
            // For the same reason this call site adds no HORIZONTAL margin: §2 owns the
            // row's `px-8` inset, and a page margin here would be a second one.
            PreviewFrame(width: 440, marginEdges: .vertical)
        )
    case "component.ui2.C-042":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-042: missing state.component")
        }
        // C-042 §4 gives no default for `label` — it is the one prop every state carries —
        // so a nil is a fixture bug, not a value to guess. `value`, `tags` and `indicator`
        // are optional by contract (they ARE the §3 state axis), and §4 spells `multiline`
        // as a plain Bool whose designed value is false in five of the six states, which is
        // the contract's default rather than an invented one. `onTap` is interaction-bearing
        // and defaulted to a no-op in the view (OQ-PB-3).
        guard let ui2C042Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-042: missing props.label")
        }
        var ui2C042Indicator: UI2Preview.EditableFieldRow.Indicator?
        if let spec = c.indicator {
            guard let tone = UI2Preview.EditableFieldRow.Indicator.Tone(rawValue: spec.tone) else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-042: props.indicator.tone must be positive|negative"
                )
            }
            ui2C042Indicator = .init(text: spec.text, tone: tone)
        }
        return declareCase(
            UI2Preview.EditableFieldRow(
                label: ui2C042Label,
                value: c.value,
                tags: c.tags,
                indicator: ui2C042Indicator,
                multiline: c.multiline ?? false
            ),
            // OQ-PB-1 default: the contract's master width. §1 deviation 2 — "Set symbols
            // are 376pt wide; consumers render at their content width (members-profile:
            // 408) — width-driven, not a variant." 376 is what the frozen snapshot shows,
            // and its chevron's box right edge lands on exactly that, so 376 is what is
            // diffable.
            PreviewFrame(width: 376)
        )
    case "component.ui2.C-066":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-066: missing state.component")
        }
        // C-066 §3 is a MIXED state matrix, like C-019's: one row is the C-066 container and
        // one is C-067 ActionMenuRow, which has its own registry row but ships inside C-066's
        // contract file and therefore owns no comparison row of its own. Both units render
        // through this one case, dispatched on `actions` — C-066's prop alone.
        if let actions = c.actions {
            // §4 gives no default for `actions`: it IS the component, so a nil is a fixture
            // bug, not a value to guess. `onSelect` / `onDone` are interaction-bearing and
            // defaulted to no-ops in the view (OQ-PB-3).
            return AnyView(
                UI2Preview.ActionMenuOverlay(
                    actions: actions.map {
                        UI2Preview.ActionMenuOverlay.ActionItem(glyph: $0.glyph, label: $0.label)
                    }
                )
                // OQ-PB-1 default: the contract's master width. §2 — "432pt wide in the
                // frame (content 384)" — and §1 deviation 3 makes only the HEIGHT
                // content-driven, so the width is pinned and the height is not. The frozen
                // snapshot is exactly 432×212 with the panel bleeding to its edges, which is
                // why this call site adds no page margin: the snapshot has none to match.
                .frame(width: 432)
                .frame(maxWidth: .infinity)             // fill the device width the runner renders at
                .background(UI2Preview.Token.layoutBackground)  // OQ-PB-2 default
            )
        }
        // §4 (C-067) gives no default for `glyph` or `label` — together they are the whole of
        // the row — so a nil in either is a fixture bug. `onTap` is a no-op in the view.
        guard let glyph = c.glyph else {
            throw ViewRegistryError.unknownView("component.ui2.C-066: missing props.glyph")
        }
        guard let label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-066: missing props.label")
        }
        return AnyView(
            UI2Preview.ActionMenuRow(glyph: glyph, label: label)
                // OQ-PB-1: C-067 states no master width of its own — it is width-driven
                // inside C-066. §2's "content 384" is the width the frozen snapshot renders
                // it at, so it is the width at which the row's chevron lands where the
                // snapshot has it.
                .frame(width: 384)
                .padding(UI2Preview.Token.Space.rowGap)   // §2's p24, so the row sits where C-066 puts it
                .frame(maxWidth: .infinity)
                .background(UI2Preview.Token.modalBackground)   // §2: the surface C-067 always renders on
        )
    // "component.ui2.C-025" — RETIRED 2026-09-21 by `/d2m-component-merge C-023 C-025`:
    // C-025 DayActivityCard was merged into C-023 RailCard as `kind=day`, its fixture retired
    // with its row, and its view (DayActivityCard.swift) removed. The merged view — both
    // kinds, one case "component.ui2.C-023" below — was written by `/d2m-component-build
    // C-023` (2026-09-21) from the merged contract. The decoding fields the C-025 case introduced
    // (CaptureFixture.swift: `state`, `percent`, `details`, `date`, `weekday`, `dateState`,
    // `line1`, `line2`, `detailsState`, the retyped `day`) stay — additive optionals are
    // never removed — and are re-commented there to name C-023.

    case "component.ui2.C-033":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-033: missing state.component")
        }
        let ui2C033Style: UI2Preview.GroupFollowCard.Style
        switch c.style {
        case "default": ui2C033Style = .standard
        case "noBar": ui2C033Style = .noBar
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-033: props.style must be default|noBar")
        }
        let ui2C033Color: UI2Preview.GroupFollowCard.BandColor
        switch c.color {
        case "green": ui2C033Color = .green
        case "yellow": ui2C033Color = .yellow
        case "red": ui2C033Color = .red
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-033: props.color must be green|yellow|red")
        }
        // Seed the photo synchronously so the snapshot's single layout pass can render it.
        // Same mechanism, and the same reason, as CaptureEnvironment's 1.0 image seeding:
        // an `AsyncImage` task cannot finish inside that pass. `UI2Preview` imports SwiftUI
        // only, so it has its own cache (UI2Preview/Ui2ImageCache.swift) rather than
        // `MakeReady.ImageCache`.
        if let photo = c.photoURL, let photoURL = URL(string: photo),
           photoURL.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        // C-033 §4 gives a default for exactly one prop — `showLink` (§3d: "boolean prop,
        // default true") — so that is the only `??` with a contract behind it. `title` and
        // `percent` are required in both states, and a nil there is a fixture bug.
        guard let ui2C033Title = c.title, let ui2C033Percent = c.percent?.stringValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-033: props.title and props.percent are required")
        }
        return declareCase(
            UI2Preview.GroupFollowCard(
                style: ui2C033Style,
                color: ui2C033Color,
                title: ui2C033Title,
                photoURL: c.photoURL,
                // §4 scopes `members` and `label` to `noBar`, so their absence in `Default` is
                // the contract, not a missing default — and `Default` renders neither (it
                // hard-codes "complete", deviation 7).
                members: c.members ?? "",
                percent: ui2C033Percent,
                label: c.label ?? "",
                showLink: c.showLink ?? true,
                // §4 scopes `progress` to `default`; `noBar` draws no bar at all.
                progress: c.progress ?? 0
            ),
            // OQ-PB-1: C-033 §2 opens "179×228 in every state", so the component states its
            // own footprint and the call site does not fix one — it only supplies the outer
            // margin and the ground.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-046":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: missing state.component")
        }
        // C-046 §4 gives no default for `label`, `field`, `style`, `layout` or `placeholder`,
        // so a nil is a fixture bug, not a value to guess. `text` defaults to "" — C-045 §4's
        // own "empty → placeholder shows", which C-046 §4 delegates to verbatim.
        guard let label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: missing props.label")
        }
        guard let fieldRaw = c.field, let field = UI2Preview.FieldGroup.Field(rawValue: fieldRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: props.field must be Text|Multiline Text|Phone")
        }
        guard let styleRaw = c.style, let ui2C046Style = UI2Preview.FieldGroup.Style(rawValue: styleRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: props.style must be Default|Focus")
        }
        guard let layoutRaw = c.layout, let ui2C046Layout = UI2Preview.FieldGroup.Layout(rawValue: layoutRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: props.layout must be Default|Centered")
        }
        guard let ui2C046Placeholder = c.placeholder else {
            throw ViewRegistryError.unknownView("component.ui2.C-046: missing props.placeholder")
        }
        return declareCase(
            UI2Preview.FieldGroup(
                label: label,
                field: field,
                style: ui2C046Style,
                layout: ui2C046Layout,
                text: c.text ?? "",
                placeholder: ui2C046Placeholder
            ),
            PreviewFrame(width: 387)  // OQ-PB-1 default: C-046 §1 deviation 2 master width
        )
    case "component.ui2.C-038":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-038: missing state.component")
        }
        // C-038 §4 gives no default for `size`, so a nil is a fixture bug, not a value to guess.
        // `imageURL` and `initials` are optional outright — each state supplies only the content
        // it draws (§3a).
        guard let ui2C038Size = c.size?.doubleValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-038: missing props.size")
        }
        let ui2C038ImageURL = c.imageURL.flatMap(URL.init(string:))
        // C-038 §4 `shape` / `selected` — host-set, so a missing value takes the contract's
        // default (`round` / `false`). `shape` reuses the existing `shape` field and `selected`
        // the retyped `selected` field (`.boolValue`, as C-047 does) — no new field.
        let ui2C038Shape: UI2Preview.Avatar.Shape
        if let ui2C038ShapeRaw = c.shape {
            guard let parsed = UI2Preview.Avatar.Shape(rawValue: ui2C038ShapeRaw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-038: props.shape must be round|square")
            }
            ui2C038Shape = parsed
        } else {
            ui2C038Shape = .round
        }
        let ui2C038Selected = c.selected?.boolValue ?? false
        // OQ-C-038-3 (d): state is derived-only, so the view takes no `state`. The fixture still
        // carries the §3 label; it must agree with what the content derives, or the preview
        // would be captured under the wrong label.
        let ui2C038Derived = UI2Preview.Avatar.derive(imageURL: ui2C038ImageURL, initials: c.initials)
        if let ui2C038Raw = c.state, ui2C038Raw != ui2C038Derived.rawValue {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-038: props.state \(ui2C038Raw) disagrees with the content, which derives \(ui2C038Derived.rawValue)")
        }
        // Seed the photo synchronously so the snapshot's single layout pass can render it —
        // same mechanism and same reason as the C-033 case above.
        if let photoURL = ui2C038ImageURL, photoURL.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        return declareCase(
            UI2Preview.Avatar(
                imageURL: ui2C038ImageURL,
                initials: c.initials,
                size: CGFloat(ui2C038Size),
                shape: ui2C038Shape,
                selected: ui2C038Selected
            ),
            // C-038 §3b — the set designs ONE diameter and the component states its own
            // footprint, so the call site fixes no width; it supplies the outer margin and the
            // ground only.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-062":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-062: missing state.component")
        }
        // C-062 §4 gives no default for either prop, so a nil is a fixture bug, not a value to
        // guess. `percent` reuses the retyped `percent` field (`.intValue`, as the retired C-025 case did — now C-023 `kind=day`) and
        // `size` the retyped `size` field (`.stringValue`, as the 1.0 cards do) — both carry
        // the contract's own prop names, so neither needed a new field.
        guard let ui2C062Percent = c.percent?.intValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-062: missing props.percent")
        }
        guard let ui2C062Raw = c.size?.stringValue,
              let ui2C062Size = UI2Preview.PercentDisc.Size(rawValue: ui2C062Raw) else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-062: props.size must be Green 1|Green 2|Yellow 1|Yellow 2|Red 1|size6")
        }
        return declareCase(
            UI2Preview.PercentDisc(percent: ui2C062Percent, size: ui2C062Size),
            // OQ-PB-1: C-062 §2/§3c — the slot is 80×80 in EVERY variant, so the component
            // states its own footprint and the call site fixes no width; it supplies the
            // outer margin and the ground only.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-053":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-053: missing state.component")
        }
        // C-053 §4 has exactly one prop and gives it no default, so a nil is a fixture bug,
        // not a value to guess. It reuses the existing `state` field under the contract's own
        // prop name (CaptureFixture.swift) — no new field.
        guard let ui2C053Raw = c.state,
              let ui2C053State = UI2Preview.StatusBadge.State(rawValue: ui2C053Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-053: props.state must be published|draft")
        }
        return declareCase(
            UI2Preview.StatusBadge(state: ui2C053State),
            // OQ-PB-1: C-053 §3b — "Width is not a variant": the pill hugs its label, so
            // the component states its own footprint and the call site fixes no width; it
            // supplies the outer margin and the ground only.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-027":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-027: missing state.component")
        }
        // C-027 §4 gives no prop a default, so a nil is a fixture bug, not a value to guess.
        // Both props reuse existing fields under the contract's own names — no additions.
        //
        // `color`'s value set is owned by tokens.md (§4), not by an enum on the view, so the
        // fixture carries the TOKEN ROW NAME and it resolves here. An unknown name throws
        // rather than defaulting: a typo must not render as a plausible colour.
        guard let ui2C027ColorName = c.color else {
            throw ViewRegistryError.unknownView("component.ui2.C-027: missing props.color")
        }
        let ui2C027Color: Color
        switch ui2C027ColorName {
        case "color-accent":   ui2C027Color = UI2Preview.Token.accent
        case "color-white-20": ui2C027Color = UI2Preview.Token.white20
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-027: props.color '\(ui2C027ColorName)' is not a tokens.md colour this case resolves")
        }
        guard let ui2C027Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-027: missing props.label")
        }
        return declareCase(
            UI2Preview.LegendItem(color: ui2C027Color, label: ui2C027Label),
            // OQ-PB-1: C-027 §3b — "Width is not a variant": the row hugs its label, so
            // the component states its own footprint and the call site fixes no width; it
            // supplies the outer margin and the ground only.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-022":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-022: missing state.component")
        }
        // C-022 §4 gives no prop a default, so a nil is a fixture bug, not a value to guess.
        // `value` and `label` reuse existing fields under the contract's own names, and so does
        // `align` — the struct's `align` is C-024's, the same name and the same `String?`, so
        // rule 3's second bound is satisfied without a rename. Only `layout` is additive.
        guard let ui2C022Value = c.value else {
            throw ViewRegistryError.unknownView("component.ui2.C-022: missing props.value")
        }
        guard let ui2C022Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-022: missing props.label")
        }
        guard let ui2C022LayoutRaw = c.layout,
              let ui2C022Layout = UI2Preview.MetaPair.Layout(rawValue: ui2C022LayoutRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-022: props.layout must be inline|stacked")
        }
        // C-022 §4: "`align` is inert under `layout=stacked`. That is a sparse matrix, not a
        // missing state." So the stacked state carries no `align` key and `.left` is passed as
        // the unread placeholder — `stackedColumn` never reads it, and §3d declines to propose a
        // stacked `align` rather than inventing one. Under `inline` the key is required: both
        // orders are designed (§3a), so a nil there IS a fixture bug.
        let ui2C022Align: UI2Preview.MetaPair.Align
        switch ui2C022Layout {
        case .stacked:
            ui2C022Align = .left
        case .inline:
            guard let raw = c.align, let parsed = UI2Preview.MetaPair.Align(rawValue: raw) else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-022: props.align must be Left|Right when layout=inline")
            }
            ui2C022Align = parsed
        }
        return declareCase(
            UI2Preview.MetaPair(
                value: ui2C022Value,
                label: ui2C022Label,
                layout: ui2C022Layout,
                align: ui2C022Align,
                // C-022 §4 gives `valueFirst` a default — `false`, the drawn order — so a missing
                // key is the contract's own value here, not a guess. Inert under `layout=inline`.
                valueFirst: c.valueFirst ?? false
            ),
            // OQ-PB-1: C-022 §3c — "Width is not a variant … every form hugs its content", and
            // §2 sets neither height. The contract states no master width, so the call site
            // fixes none; it supplies the outer margin and the ground only, as C-027's does.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-052":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-052: missing state.component")
        }
        // C-052 §4 gives neither rendering prop a default (R-07), so a nil is a fixture bug,
        // not a value to guess. `content` decodes C-052's `DayChip.Content` object through the
        // either-shape `CaptureContentOrChildren` (C-091's slot is the other shape); `state`
        // reuses the existing `String?` field under the contract's own name.
        let ui2C052Content: UI2Preview.DayChip.Content
        switch (c.content?.dayChip?.day, c.content?.dayChip?.weekday) {
        case let (day?, nil):
            ui2C052Content = .day(day)
        case let (nil, weekday?):
            ui2C052Content = .weekday(letter: weekday.letter, name: weekday.name)
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-052: props.content must be {\"day\": n} or {\"weekday\": {\"letter\", \"name\"}}"
            )
        }
        guard let ui2C052Raw = c.state,
              let ui2C052State = UI2Preview.DayChip.State(rawValue: ui2C052Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-052: props.state must be Default|Active")
        }
        return declareCase(
            UI2Preview.DayChip(content: ui2C052Content, state: ui2C052State),
            // C-052 §2 fixes the component's own footprint (32×40 day, 32×32 weekday), so the
            // call site fixes no width — it supplies the outer margin and the ground only.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-057":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-057: missing state.component")
        }
        // C-057 §4 gives `progress` no default, so a nil is a fixture bug, not a value to guess.
        guard let ui2C057Progress = c.progress else {
            throw ViewRegistryError.unknownView("component.ui2.C-057: props.progress is required")
        }
        // note 2026-09-12T02:28:29.097Z renames §4's `style` {Thick, Thin} to a t-shirt `size`;
        // the fixture carries lg/sm, which are the note's names for the two DESIGNED heights.
        // `md` and `xs` (OQ-C-125-001) are §3 rows of their own.
        guard let ui2C057SizeRaw = c.size?.stringValue,
              let ui2C057Size = UI2Preview.PercentBar.Size(rawValue: ui2C057SizeRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-057: props.size must be xs|sm|md|lg")
        }
        guard let ui2C057AlignedRaw = c.aligned,
              let ui2C057Aligned = UI2Preview.PercentBar.Aligned(rawValue: ui2C057AlignedRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-057: props.aligned must be Right|Left")
        }
        // note 2026-09-12T02:28:29.097Z: solid is the default fill.
        let ui2C057FillStyle: UI2Preview.PercentBar.FillStyle
        if let raw = c.fillStyle {
            guard let parsed = UI2Preview.PercentBar.FillStyle(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-057: props.fillStyle must be solid|gradient")
            }
            ui2C057FillStyle = parsed
        } else {
            ui2C057FillStyle = .solid
        }
        // note 2026-09-12T02:28:29.097Z: the colour is an OVERRIDE — nil derives it from the
        // thresholds. Carried as a tokens.md row name, the way C-027's `color` is, because
        // SwiftLint forbids `Color(hex:)` and an unrecognised name must throw rather than
        // render a plausible colour.
        var ui2C057FillColor: Color?
        if let name = c.fillColor {
            switch name {
            case "color-positive": ui2C057FillColor = UI2Preview.Token.positive
            case "color-warning":  ui2C057FillColor = UI2Preview.Token.warning
            case "color-negative": ui2C057FillColor = UI2Preview.Token.negative
            case "color-accent":   ui2C057FillColor = UI2Preview.Token.accent
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-057: props.fillColor '\(name)' is not a tokens.md colour this case resolves")
            }
        }
        // note 2026-09-12T02:28:29.097Z: "there should be a default applied 0.2 red, 0.4 yellow
        // 0.7 green" — supplied by the view, so a missing key is the note's own value.
        let ui2C057Thresholds = c.thresholds.map {
            UI2Preview.PercentBar.Thresholds(red: $0.red, yellow: $0.yellow, green: $0.green)
        } ?? .standard
        // Omitted by every fixture on purpose: an animating fill would race the capture.
        var ui2C057Animation: UI2Preview.PercentBar.FillAnimation?
        if let a = c.fillAnimation {
            guard let easing = UI2Preview.PercentBar.Easing(rawValue: a.easing) else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-057: props.fillAnimation.easing must be linear|easeIn|easeOut|easeInOut")
            }
            ui2C057Animation = UI2Preview.PercentBar.FillAnimation(duration: a.duration, easing: easing)
        }
        return declareCase(
            UI2Preview.PercentBar(
                progress: ui2C057Progress,
                fillColor: ui2C057FillColor,
                size: ui2C057Size,
                aligned: ui2C057Aligned,
                fillStyle: ui2C057FillStyle,
                thresholds: ui2C057Thresholds,
                fillAnimation: ui2C057Animation
            ),
            // OQ-PB-1: C-057 §1 deviation 2 — "The track width is the sheet's, not the
            // component's … The bar fills the width its host gives it and takes no width prop."
            // 255 is what the sheet draws and what the frozen snapshot measures, so the call
            // site pins it: the diff is against that render, not against a device-width bar.
            PreviewFrame(width: 255, alignment: .leading)
        )
    case "component.ui2.C-035":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-035: missing state.component")
        }
        // C-035 §4 `type` enumerates its values, so an unrecognised one must throw rather than
        // fall back to a plausible presentation.
        guard let ui2C035TypeRaw = c.type,
              let ui2C035Type = UI2Preview.FilterChip.ChipType(rawValue: ui2C035TypeRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-035: props.type must be Menu|Button|Font")
        }
        // §4 gives `active` and `label` no default (R-07) — a nil is a fixture bug.
        guard let ui2C035Active = c.active else {
            throw ViewRegistryError.unknownView("component.ui2.C-035: props.active is required")
        }
        guard let ui2C035Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-035: props.label is required")
        }
        // §4: "`font` is required in `type=Font`" and ignored by the other types. The value set is
        // C-092's (`CanvasTextObject.Font`), decoded exactly as C-092's own case decodes it.
        var ui2C035Font: UI2Preview.CanvasTextObject.Font?
        switch c.font {
        case "poppins": ui2C035Font = .poppins
        case "sfPro": ui2C035Font = .sfPro
        case "georgia": ui2C035Font = .georgia
        case "typewriter": ui2C035Font = .typewriter
        case nil: ui2C035Font = nil
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-035: props.font must be poppins|sfPro|georgia|typewriter")
        }
        if ui2C035Type == .font && ui2C035Font == nil {
            throw ViewRegistryError.unknownView("component.ui2.C-035: props.font is required in type=Font")
        }
        // NO width frame: C-035 §3b — every type hugs its label, so the preview fills the device
        // width leading-aligned and a bare capture is the chip at its own size.
        return declareCase(
            UI2Preview.FilterChip(
                type: ui2C035Type,
                active: ui2C035Active,
                label: ui2C035Label,
                font: ui2C035Font
            ),
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-064":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-064: missing state.component")
        }
        // C-064 §4 gives neither prop a default — the `3`/`3` Figma renders are sample content
        // (§1 deviation 1), not the contract's defaults — so a nil is a fixture bug, not a value
        // to guess.
        guard let ui2C064Months = c.months else {
            throw ViewRegistryError.unknownView("component.ui2.C-064: props.months is required")
        }
        // `days` is the polymorphic `CaptureDays`; C-064 §4 types it `Int`, which is the field's
        // `.duration` branch. C-026 reads `.timeline` from the same field.
        guard let ui2C064Days = c.days?.duration else {
            throw ViewRegistryError.unknownView("component.ui2.C-064: props.days must be an Int")
        }
        return declareCase(
            UI2Preview.DateSpanIndicator(months: ui2C064Months, days: ui2C064Days),
            // OQ-PB-1: C-064 §2 fixes the component's own footprint at 184×88 (§1 deviation
            // 5: "The 88 and the 184 **are** set"), so the call site fixes no width — it
            // supplies the outer margin and the ground only, as C-052's and C-053's do.
            // Whether that box is designed or authoring residue is OQ-C-064-2; if the owner
            // rules "hug the content", the frame comes off the view, not off this line.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-047":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-047: missing state.component")
        }
        // C-047 §4 gives `title` and `selected` no default — "Private" and the two Figma
        // symbols' `state` are sample content (§1 deviation 1), not the contract's defaults —
        // so a nil is a fixture bug, not a value to guess. `description` is `String?` in §4
        // itself: nil IS the contract's title-only configuration, so it passes through as is.
        guard let ui2C047Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-047: props.title is required")
        }
        // `selected` decodes Bool-or-String since the C-028 retype (CaptureFixture.swift); C-047's
        // is the Bool, so a String here is as much a fixture bug as a missing key.
        guard let ui2C047Selected = c.selected?.boolValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-047: props.selected is required")
        }
        return declareCase(
            UI2Preview.RadioOptionRow(
                title: ui2C047Title,
                description: c.description,
                selected: ui2C047Selected,
                // §4 gives both a default of `false`, so a missing key is that default.
                recommended: c.recommended ?? false,
                disabled: c.disabled ?? false
            ),
            // OQ-PB-1: C-047 §1 deviation 2 — "The symbols are 408 wide; the row is
            // width-driven by its consumer." 408 is the sampled width the frozen snapshot
            // measures, so the call site pins it: the diff is against that render, and the
            // sampled description wraps to the same two lines it does in Figma.
            PreviewFrame(width: 408, alignment: .leading)
        )
    case "component.ui2.C-048":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-048: missing state.component")
        }
        // C-048 §4 gives `label` and `role` no default, so a nil is a fixture bug, not a value
        // to guess. `role` enumerates its values, so an unrecognised one must throw rather than
        // fall back to a plausible paint row (rule 5's one-owner rule, read from this side).
        guard let ui2C048Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-048: props.label is required")
        }
        guard let ui2C048RoleRaw = c.role,
              let ui2C048Role = UI2Preview.PageActionButton.Role(rawValue: ui2C048RoleRaw) else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-048: props.role must be affirmative|destructive|prominent|secondary|accent")
        }
        // C-048 §4 #3: `size` defaults to `.md`. It reuses the existing `size` field
        // (CaptureDoubleOrString, read as its string — the C-092 / card precedent).
        var ui2C048Size = UI2Preview.PageActionButton.Size.md
        if let raw = c.size?.stringValue {
            guard let s = UI2Preview.PageActionButton.Size(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-048: props.size must be md|lg")
            }
            ui2C048Size = s
        }
        // C-048 §4 #3–#5: `glyph` is any library glyph (nil = label-only); `glyphPosition` and
        // `layout` default to `.trailing` / `.spread`. A value outside a closed set throws.
        var ui2C048Glyph: UI2Preview.GlyphName?
        if let raw = c.glyph {
            guard let g = UI2Preview.GlyphName(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-048: props.glyph '\(raw)' is not a library glyph")
            }
            ui2C048Glyph = g
        }
        var ui2C048GlyphPosition = UI2Preview.PageActionButton.GlyphPosition.trailing
        if let raw = c.glyphPosition {
            guard let p = UI2Preview.PageActionButton.GlyphPosition(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-048: props.glyphPosition must be leading|trailing")
            }
            ui2C048GlyphPosition = p
        }
        var ui2C048Layout = UI2Preview.PageActionButton.Layout.spread
        if let raw = c.layout {
            guard let l = UI2Preview.PageActionButton.Layout(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-048: props.layout must be spread|centered")
            }
            ui2C048Layout = l
        }
        return declareCase(
            UI2Preview.PageActionButton(
                label: ui2C048Label,
                role: ui2C048Role,
                size: ui2C048Size,
                glyph: ui2C048Glyph,
                glyphPosition: ui2C048GlyphPosition,
                layout: ui2C048Layout,
                // C-048 §4 gives `enabled` a default — `true` — so a missing key is the
                // contract's own value here, not a guess.
                enabled: c.enabled ?? true
            ),
            // OQ-PB-1: C-048 §2 — "**Width is the consumer's.** The symbols hug their label;
            // every consumer stretches the button to its content width — 408 on the 440pt screen
            // frames … Hug width is sheet presentation only and is never rendered in a screen."
            // So the call site pins 408, the width both screen consumers use. The frozen snapshot
            // is the SET at hug width, so width is not comparable against it by construction —
            // height, paint, radius and type are.
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-039":
        guard fixture.state?.component != nil else {
            throw ViewRegistryError.unknownView("component.ui2.C-039: missing state.component")
        }
        // C-039 §4 has exactly one prop, `action`, which is interaction-bearing and defaulted
        // to a no-op in the view — so the `default` state's prop bag is authored empty and
        // nothing on `c` is read. §1 deviation 1: there is no variant prop to decode.
        return declareCase(
            UI2Preview.ClearSearchButton(),
            // No master width to pin (OQ-PB-1): like C-021 this component states its own
            // footprint — §2's 32×32 frame — so the call site adds only the page margin
            // and the ground. §1 deviation 2: the frozen snapshot is framed over the design
            // file's page ground `#030405` = `color-layout-background`, and the component
            // itself paints no fill, so that ground lives HERE, not in the view.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-028":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-028: missing state.component")
        }
        // C-028 §4 gives neither `options` nor `selected` a default, so a nil is a fixture
        // bug, not a value to guess. Both reuse existing fields under the contract's own
        // names: `options` decodes `[String]` (`.strings`, retyped for C-036); `selected` was `Bool?` and is retyped to
        // decode Bool-or-String (CaptureFixture.swift) — C-028's is the String.
        guard let ui2C028Options = c.options?.strings else {
            throw ViewRegistryError.unknownView("component.ui2.C-028: props.options is required")
        }
        guard let ui2C028Selected = c.selected?.stringValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-028: props.selected (String) is required")
        }
        return declareCase(
            UI2Preview.InlineDropdown(options: ui2C028Options, selected: ui2C028Selected),
            // OQ-PB-1: C-028 §3b — "Width is not a variant": the row hugs its label, so the
            // component states its own footprint (61×24 at "All time") and the call site
            // fixes no width; it supplies the outer margin and the ground only. §2:
            // "Placement is the consumer's, not this row's."
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-049":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-049: missing state.component")
        }
        // C-049 §4 gives `label` no default, so a nil is a fixture bug, not a value to guess.
        // `style` enumerates its values and defaults to `default`, so a MISSING key is the
        // contract's own value while an unrecognised one must throw (rule 5's one-owner rule).
        guard let ui2C049Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-049: props.label is required")
        }
        let ui2C049Style: UI2Preview.LinkButton.Style
        if let raw = c.style {
            guard let parsed = UI2Preview.LinkButton.Style(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-049: props.style must be default|muted")
            }
            ui2C049Style = parsed
        } else {
            ui2C049Style = .default
        }
        return declareCase(
            UI2Preview.LinkButton(
                label: ui2C049Label,
                style: ui2C049Style,
                // C-049 §4 gives `isEnabled` a default — `true` — so a missing key is the
                // contract's own value here, not a guess.
                isEnabled: c.isEnabled ?? true
            ),
            // OQ-PB-1: C-049 §2 — "**Hug-width** — the component is as wide as its label and
            // never stretches", so the call site fixes no width; it supplies the outer margin
            // and the ground only, leading-aligned as both consumers place it (C-051 leading
            // under the prompt; C-020 trailing in its header row — a consumer's choice).
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-077":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: missing state.component")
        }
        // C-077 §4 gives no prop a default — the "25%" / "0%" Figma renders are sample
        // content (§1 deviation 1) — so a nil is a fixture bug, not a value to guess.
        // `direction` enumerates its values (rule 5's one-owner rule): an unrecognised one
        // must throw rather than render a plausible arrow. It is never derived from `label`
        // (owner ruling 2026-09-17, OQ-C-077-2).
        guard let ui2C077DirectionRaw = c.direction else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: props.direction is required")
        }
        guard let ui2C077Direction = UI2Preview.TrendIndicator.Direction(rawValue: ui2C077DirectionRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: props.direction must be up|down|neutral")
        }
        // `polarity` (owner note 2026-09-17 04:23, assimilated) enumerates its values the same
        // way and is independent of `direction` — all nine cells are legal (OQ-C-077-4), so
        // the case validates each prop alone and never the pair.
        guard let ui2C077PolarityRaw = c.polarity else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: props.polarity is required")
        }
        guard let ui2C077Polarity = UI2Preview.TrendIndicator.Polarity(rawValue: ui2C077PolarityRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: props.polarity must be positive|negative|neutral")
        }
        guard let ui2C077Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-077: props.label is required")
        }
        return declareCase(
            UI2Preview.TrendIndicator(direction: ui2C077Direction, polarity: ui2C077Polarity, label: ui2C077Label),
            // OQ-PB-1: C-077 §3b — "Width is not a variant": the row hugs its label, so
            // the component states its own footprint and the call site fixes no width; it
            // supplies the outer margin and the ground only, as C-027's does.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    default:
        return nil
    }
}

/// Part 7 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart7(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ui2.C-051":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-051: missing state.component")
        }
        // C-051 §4 gives none of its three render-bearing props a default — `state`,
        // `promptCopy` and `suggestions` are all **Required** (R-07) — so a nil is a fixture
        // bug, not a value to guess. `state` enumerates its values (rule 5's one-owner rule):
        // an unrecognised one must throw rather than render a plausible body.
        guard let ui2C051StateRaw = c.state else {
            throw ViewRegistryError.unknownView("component.ui2.C-051: props.state is required")
        }
        guard let ui2C051State = UI2Preview.AISuggestionsBlock.State(rawValue: ui2C051StateRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-051: props.state must be prompt|generating|list|regenerating")
        }
        guard let ui2C051PromptCopy = c.promptCopy else {
            throw ViewRegistryError.unknownView("component.ui2.C-051: props.promptCopy is required")
        }
        guard let ui2C051Suggestions = c.suggestions else {
            throw ViewRegistryError.unknownView("component.ui2.C-051: props.suggestions is required")
        }
        return declareCase(
            UI2Preview.AISuggestionsBlock(
                state: ui2C051State,
                promptCopy: ui2C051PromptCopy,
                suggestions: ui2C051Suggestions
            ),
            // OQ-PB-1: C-051 §2 — "full container width (deviation 1)": every designed frame
            // is 408 wide, the page's content width at the design viewport, so the call site
            // fixes that master width and supplies the outer margin and the ground.
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-050":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-050: missing state.component")
        }
        // C-050 §4 gives `title` no default — it is the whole of the row's content and is
        // **Required** (R-07) — so a nil is a fixture bug, not a value to guess. `onAdd` is
        // interaction-bearing and defaulted to a no-op in the view (R-03).
        guard let ui2C050Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-050: props.title is required")
        }
        return declareCase(
            UI2Preview.SuggestionRow(title: ui2C050Title),
            // OQ-PB-1: C-050 §1 deviation 1 — "Width is container-driven … the three consumed
            // instances in `3860:8334` are 408 (the page's content width)". The sheet symbol
            // is 304, but the consumer is what the row is for, so the call site fixes the
            // consumed width (C-051's own master width) and supplies the margin and ground.
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-078":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-078: missing state.component")
        }
        // C-078 §4 gives `suggestions` no default — "Required — no frame shows a default" (R-07)
        // — so a nil is a fixture bug, not a value to guess. `onPick` is interaction-bearing
        // and defaulted to a no-op in the view (R-03).
        guard let ui2C078Suggestions = c.suggestions else {
            throw ViewRegistryError.unknownView("component.ui2.C-078: props.suggestions is required")
        }
        return declareCase(
            UI2Preview.SuggestionRows(suggestions: ui2C078Suggestions),
            // OQ-PB-1: C-078 §1 deviation 1 — "Width is container-driven. Both designed
            // instances are 408 wide — the page's content width." The call site fixes that
            // master width (C-051's own) and supplies the margin and the ground (R-16).
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-070":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-070: missing state.component")
        }
        // C-070 §4 gives a default for nothing — all four rows are **Required** (R-07) — so a
        // missing one is a fixture bug, not a value to guess.
        guard let ui2C070Month = c.month else {
            throw ViewRegistryError.unknownView("component.ui2.C-070: props.month is required")
        }
        guard let ui2C070Weekday = c.weekday else {
            throw ViewRegistryError.unknownView("component.ui2.C-070: props.weekday is required")
        }
        // `day` is a two-shape field (CaptureFixture.swift): C-070 §4 types it `String`, so
        // this case asks for the String and never converts an Int.
        guard let ui2C070Day = c.day?.stringValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-070: props.day (String) is required")
        }
        let ui2C070State: UI2Preview.DateBlock.State
        switch c.state {
        case "default": ui2C070State = .default
        case "today": ui2C070State = .today
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-070: props.state must be default|today")
        }
        return declareCase(
            UI2Preview.DateBlock(
                month: ui2C070Month,
                weekday: ui2C070Weekday,
                day: ui2C070Day,
                state: ui2C070State
            ),
            // OQ-PB-1: C-070 §2 — "97×38 as designed, in both states … the symbol is 97 wide
            // because its one consumer slot (C-025's content width — now C-023 `kind=day`) is 97". The call site fixes
            // that master width and supplies the outer margin and the ground (R-16).
            PreviewFrame(width: 97)
        )
    case "component.ui2.C-071":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-071: missing state.component")
        }
        // C-071 §4 gives a default for nothing — `line1` and `state` are **Required** (R-07),
        // so a missing one is a fixture bug, not a value to guess. `line2` is `String?` by
        // contract: absent means nil (the two `single` states), not a default.
        guard let ui2C071Line1 = c.line1 else {
            throw ViewRegistryError.unknownView("component.ui2.C-071: props.line1 is required")
        }
        let ui2C071State: UI2Preview.ValuePair.State
        switch c.state {
        case "default": ui2C071State = .default
        case "nothing": ui2C071State = .nothing
        case "muted": ui2C071State = .muted
        case "lessonDay": ui2C071State = .lessonDay
        case "highlighted": ui2C071State = .highlighted
        case "single": ui2C071State = .single
        case "singleMuted": ui2C071State = .singleMuted
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-071: props.state must be default|nothing|muted|lessonDay|highlighted|single|singleMuted"
            )
        }
        return declareCase(
            UI2Preview.ValuePair(
                line1: ui2C071Line1,
                line2: c.line2,
                state: ui2C071State
            ),
            // OQ-PB-1: C-071 §2 — "95×36 in every state (97×36 inside C-025 — deviation 3)";
            // the symbol is 95 and the block is width-driven, so the call site fixes the
            // symbol's master width and supplies the outer margin and the ground (R-16).
            PreviewFrame(width: 95)
        )
    case "component.ui2.C-023":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-023: missing state.component")
        }
        // C-023 §4: `kind` is the absorbing axis and is required; every other prop is "required
        // within its kind and nil outside it", and "a nil where the kind needs a value is a
        // defect, not a default" — so each kind guards its own required props and throws. The
        // genuinely optional ones read straight through: `averageLabel` (nil = line only),
        // `percent` (only `percentCircle`), `line2` (C-071's single-line states).
        let ui2C023Kind: UI2Preview.RailCard.Kind
        switch c.kind {
        case "metric": ui2C023Kind = .metric
        case "day": ui2C023Kind = .day
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-023: props.kind must be metric|day")
        }
        let ui2C023Card: UI2Preview.RailCard
        let ui2C023Width: CGFloat
        switch ui2C023Kind {
        case .metric:
            guard let title = c.title else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: metric — props.title is required")
            }
            guard let series = c.series else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: metric — props.series is required")
            }
            guard let value = c.value else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: metric — props.value is required")
            }
            // `trendDirection` / `trendPolarity` take C-077's value sets (rule 5's one-owner
            // rule): an unrecognised value throws rather than rendering a plausible arrow, and
            // the pair is never validated together — all nine cells are legal (OQ-C-077-4).
            guard let directionRaw = c.trendDirection,
                  let direction = UI2Preview.TrendIndicator.Direction(rawValue: directionRaw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: metric — props.trendDirection must be up|down|neutral")
            }
            guard let polarityRaw = c.trendPolarity,
                  let polarity = UI2Preview.TrendIndicator.Polarity(rawValue: polarityRaw) else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-023: metric — props.trendPolarity must be positive|negative|neutral"
                )
            }
            guard let trendLabel = c.trendLabel else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: metric — props.trendLabel is required")
            }
            ui2C023Card = UI2Preview.RailCard(
                kind: .metric,
                title: title,
                series: series,
                averageLabel: c.averageLabel,
                value: value,
                trendDirection: direction,
                trendPolarity: polarity,
                trendLabel: trendLabel
            )
            // OQ-PB-1: C-023 §2a — "140×192 fixed"; §3d: width follows `kind` and is not a
            // prop, so the call site fixes the kind's master width (R-16).
            ui2C023Width = 140
        case .day:
            let dayState: UI2Preview.RailCard.DayState
            switch c.state {
            case "standard": dayState = .standard
            case "transparent": dayState = .transparent
            case "percentCircle": dayState = .percentCircle
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-023: day — props.state must be standard|transparent|percentCircle"
                )
            }
            guard let month = c.month else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.month is required")
            }
            guard let weekday = c.weekday else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.weekday is required")
            }
            // `day` is a two-shape field (CaptureFixture.swift): C-023 §4 types it `String`
            // (→ C-070 `day`), so this case asks for the String and never converts an Int.
            guard let day = c.day?.stringValue else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.day (String) is required")
            }
            let dateState: UI2Preview.DateBlock.State
            switch c.dateState {
            case "default": dateState = .default
            case "today": dateState = .today
            default:
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.dateState must be default|today")
            }
            // §4: `series` required in `standard` / `transparent`, nil in `percentCircle`;
            // `percent` required in `percentCircle`, nil otherwise.
            if dayState != .percentCircle, c.series == nil {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.series is required outside percentCircle")
            }
            // `percent` is a two-shape field: C-023 §4 types it `Int` (→ C-062 `percent`).
            if dayState == .percentCircle, c.percent?.intValue == nil {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.percent (Int) is required in percentCircle")
            }
            guard let line1 = c.line1 else {
                throw ViewRegistryError.unknownView("component.ui2.C-023: day — props.line1 is required")
            }
            let detailsState: UI2Preview.ValuePair.State
            switch c.detailsState {
            case "default": detailsState = .default
            case "nothing": detailsState = .nothing
            case "muted": detailsState = .muted
            case "lessonDay": detailsState = .lessonDay
            case "highlighted": detailsState = .highlighted
            case "single": detailsState = .single
            case "singleMuted": detailsState = .singleMuted
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-023: day — props.detailsState must be default|nothing|muted|lessonDay|highlighted|single|singleMuted"
                )
            }
            ui2C023Card = UI2Preview.RailCard(
                kind: .day,
                series: c.series,
                state: dayState,
                month: month,
                weekday: weekday,
                day: day,
                dateState: dateState,
                percent: c.percent?.intValue,
                line1: line1,
                line2: c.line2,
                detailsState: detailsState
            )
            // OQ-PB-1: C-023 §2b — "131×192 in every `state`"; §3d: width follows `kind`.
            ui2C023Width = 131
        }
        return declareCase(
            ui2C023Card,
            PreviewFrame(width: ui2C023Width)
        )
    case "component.ui2.C-031":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: missing state.component")
        }
        // C-031 §4 (R-07): every prop is required and none has a designed default, so a nil is
        // a fixture bug, not a value to guess. `percent` reuses the two-shape `percent` field
        // (`.intValue`, as C-062 reads it); `count` is `Int` by OQ-C-031-6 and reuses the
        // existing `count: Int?`; `label`, `progress` and `subtitle` already exist under the
        // contract's own names and types. `statusColor` is the one added field.
        guard let ui2C031Percent = c.percent?.intValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.percent (Int) is required")
        }
        guard let ui2C031Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.label is required")
        }
        guard let ui2C031Count = c.count else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.count (Int) is required")
        }
        guard let ui2C031Progress = c.progress else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.progress is required")
        }
        guard let ui2C031Subtitle = c.subtitle else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.subtitle is required")
        }
        // OQ-C-031-1: the closed set C-033 §3b reads from its own `color` field; C-031's
        // prop is `statusColor`, so it is carried under that name (rule 3's second bound).
        guard let ui2C031Raw = c.statusColor,
              let ui2C031Color = UI2Preview.EnrollmentStatusRow.StatusColor(rawValue: ui2C031Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-031: props.statusColor must be green|yellow|red")
        }
        return declareCase(
            UI2Preview.EnrollmentStatusRow(
                percent: ui2C031Percent,
                label: ui2C031Label,
                count: ui2C031Count,
                progress: ui2C031Progress,
                subtitle: ui2C031Subtitle,
                statusColor: ui2C031Color
            ),
            // OQ-PB-1: C-031 §2 — "410×64 in the set, width-driven"; the frozen snapshot is the
            // 410 symbol, so the call site pins that master width (the consumer's 408 is §1
            // deviation 3) and supplies the outer margin and the ground.
            PreviewFrame(width: 410)
        )
    case "component.ui2.C-068":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-068: missing state.component")
        }
        // C-068 §4 gives `label` no default — it is per-instance content (§1 deviation 1) — so
        // a nil is a fixture bug, not a value to guess. `style` defaults to `default` by
        // contract. Both reuse existing fields under the contract's own prop names
        // (CaptureFixture.swift `label` / `style`) — no new field.
        guard let ui2C068Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-068: missing props.label")
        }
        guard let ui2C068Style = UI2Preview.TagChip.Style(rawValue: c.style ?? "default") else {
            throw ViewRegistryError.unknownView("component.ui2.C-068: props.style must be default|solid")
        }
        return declareCase(
            UI2Preview.TagChip(label: ui2C068Label, style: ui2C068Style),
            // OQ-PB-1: C-068 §1 deviation 2 — the chip is content-width (hug), "a consumer
            // never sets its width", so the component states its own footprint and the
            // call site fixes no width; it supplies the outer margin and the ground only.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-043":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-043: missing state.component")
        }
        // C-043 §4 gives `value` no default — it is per-instance content (§1 deviation 1) — so
        // a nil is a fixture bug, not a value to guess. `label` defaults to nil (`Single`),
        // `state` to `default` and `labelPosition` to `trailing`, all by contract. `value` /
        // `label` / `state` reuse existing fields; `labelPosition` is its own field
        // (CaptureFixture.swift, added 2026-10-24 with the OQ-C-043-1 rename).
        guard let ui2C043Value = c.value else {
            throw ViewRegistryError.unknownView("component.ui2.C-043: missing props.value")
        }
        guard let ui2C043State = UI2Preview.MetaChip.State(rawValue: c.state ?? "default") else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-043: props.state must be default|accent|complete|highlighted|muted")
        }
        guard let ui2C043LabelPosition = UI2Preview.MetaChip.LabelPosition(
            rawValue: c.labelPosition ?? "trailing") else {
            throw ViewRegistryError.unknownView("component.ui2.C-043: props.labelPosition must be trailing|leading")
        }
        return declareCase(
            UI2Preview.MetaChip(
                value: ui2C043Value,
                label: c.label,
                state: ui2C043State,
                labelPosition: ui2C043LabelPosition
            ),
            // OQ-PB-1: C-043 §1 deviation 2 — the chip is content-width (hug), "a consumer
            // never sets its width", so the component states its own footprint and the
            // call site fixes no width; it supplies the outer margin and the ground only,
            // as C-068's does.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-076":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-076: missing state.component")
        }
        // C-076 §4 defaults every prop to the designed value, so a missing key is the
        // contract's own default, never a guess. `period` is not read: the shared `period`
        // field is a String (CaptureComponent), and a static capture is phase 0 at any period.
        var ui2C076Color = UI2Preview.Token.accent
        if let name = c.color {
            switch name {
            case "color-accent":        ui2C076Color = UI2Preview.Token.accent
            case "color-text-primary":  ui2C076Color = UI2Preview.Token.textPrimary
            case "color-positive":      ui2C076Color = UI2Preview.Token.positive
            case "color-negative":      ui2C076Color = UI2Preview.Token.negative
            case "color-highlight":     ui2C076Color = UI2Preview.Token.highlight
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-076: props.color '\(name)' is not a colour token this case resolves")
            }
        }
        var ui2C076Direction = UI2Preview.ActivitySpinner.RotationDirection.clockwise
        if let raw = c.direction {
            switch raw {
            case "clockwise":        ui2C076Direction = .clockwise
            case "counterclockwise": ui2C076Direction = .counterclockwise
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-076: props.direction must be clockwise|counterclockwise")
            }
        }
        return declareCase(
            UI2Preview.ActivitySpinner(
                size: CGFloat(c.size?.doubleValue ?? 24),
                strokeWidth: CGFloat(c.strokeWidth ?? 2),
                color: ui2C076Color,
                direction: ui2C076Direction
            )
                // C-076 §2 Pose: the drawn frame is phase 0. The spin starts in onAppear; with
                // animations off it jumps straight to one full turn, which IS phase 0, so the
                // capture cannot catch the ring mid-turn.
                .transaction { $0.disablesAnimations = true },
            // OQ-PB-1: C-076 §2 — "a glyph states a fixed intrinsic size", so the call site
            // fixes no width; it supplies the outer margin and the ground only, as C-043's does.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-020":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-020: missing state.component")
        }
        // C-020 §4: `title` is **Required**, so a nil is a fixture bug. `style` defaults to
        // `.section` and `accessory` to `.none`, both by contract. `title` / `style` reuse the
        // existing fields; `accessory` is the one new field (CaptureUI2SectionAccessory).
        guard let ui2C020Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-020: props.title is required")
        }
        guard let ui2C020Style = UI2Preview.SectionHeader.Style(rawValue: c.style ?? "section") else {
            throw ViewRegistryError.unknownView("component.ui2.C-020: props.style must be section|block")
        }
        let ui2C020Accessory: UI2Preview.SectionHeader.Accessory
        if let a = c.accessory?.meta {
            guard let glyph = UI2Preview.GlyphButton.Glyph(rawValue: a.glyph) else {
                throw ViewRegistryError.unknownView("component.ui2.C-020: accessory.meta.glyph is not a C-021 glyph")
            }
            ui2C020Accessory = .meta(value: a.value, label: a.label, glyph: glyph)
        } else if let a = c.accessory?.link {
            guard let linkStyle = UI2Preview.LinkButton.Style(rawValue: a.style) else {
                throw ViewRegistryError.unknownView("component.ui2.C-020: accessory.link.style must be default|muted")
            }
            ui2C020Accessory = .link(label: a.label, style: linkStyle)
        } else if let a = c.accessory?.dropdown {
            ui2C020Accessory = .dropdown(label: a.label)
        } else if let a = c.accessory?.caption {
            guard let glyph = UI2Preview.GlyphButton.Glyph(rawValue: a.glyph) else {
                throw ViewRegistryError.unknownView("component.ui2.C-020: accessory.caption.glyph is not a C-021 glyph")
            }
            ui2C020Accessory = .caption(label: a.label, glyph: glyph)
        } else {
            ui2C020Accessory = .none
        }
        return declareCase(
            UI2Preview.SectionHeader(title: ui2C020Title, style: ui2C020Style, accessory: ui2C020Accessory),
            // OQ-PB-1: C-020 §2 — width-driven (R-16); every live instance's content width is
            // 408 (440 with px16, or 408 at x16 — §1 deviation 1), so the call site fixes that
            // master width and supplies the outer margin and the ground.
            PreviewFrame(width: 408)
        )
    case "screen.2.0.edit-text-single-field":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.edit-text-single-field: missing state.component")
        }
        // A missing field takes this build's `clean` sample (§2's Group name content table).
        let screen = UI2Preview.EditTextSingleFieldScreen(
            state: .init(
                title: c.title ?? "Group name",
                description: c.description ?? "The group name is the primary title for your group that will be surfaced anytime the group is displayed in a MakeReady app",
                label: c.label ?? "Group name",
                placeholder: c.placeholder ?? "",
                text: c.text ?? "Young professionals",
                loadedValue: c.loadedValue ?? "Young professionals",
                focused: c.focused ?? false,
                saving: c.saving ?? false,
                promptCopy: c.promptCopy ?? "If you need help coming up with a name for your group, MakeReady AI can analyze your content and provide suggestions.",
                aiState: c.aiState ?? "prompt",
                suggestions: c.suggestions ?? []
            )
        )
        // The canvas: devices[0]'s width (iphone-16-pro-max, 440pt) × the linked frame's height.
        if let height = c.__frameHeight {
            return AnyView(screen.frame(width: 440, height: CGFloat(height), alignment: .top))
        }
        return AnyView(screen.frame(width: 440))
    case "screen.2.0.edit-option-field":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.edit-option-field: missing state.component")
        }
        // A missing field takes this build's `clean` sample (the Visibility Use, frozen frame).
        let screen = UI2Preview.EditOptionFieldScreen(
            state: .init(
                title: c.title ?? "Visibility",
                description: c.description ?? "Visibility determines who is able to view the group",
                options: c.options?.strings ?? ["Private", "Public"],
                optionDescriptions: c.optionDescriptions ?? [
                    "Only active members of the group can view information about the group, organization, and group leader.",
                    "Anyone can search and view information about the group and the group leader."
                ],
                loadedValue: c.loadedValue ?? "Private",
                selectedOption: c.selectedOption ?? "Private",
                saving: c.saving ?? false,
                errorMessage: c.errorMessage ?? ""
            )
        )
        // The canvas: devices[0]'s width (iphone-16-pro-max, 440pt) × the linked frame's height.
        if let height = c.__frameHeight {
            return AnyView(screen.frame(width: 440, height: CGFloat(height), alignment: .top))
        }
        return AnyView(screen.frame(width: 440))
    case "screen.2.0.edit-options-custom-field":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.edit-options-custom-field: missing state.component")
        }
        // A missing field takes this build's `clean` sample (the Age-range instance, frozen frame).
        let screen = UI2Preview.EditOptionsCustomFieldScreen(
            state: .init(
                title: c.title ?? "Age range",
                description: c.description ?? "If an age range is specified, then every member who joins must fall within the specified range.",
                options: c.options?.strings ?? ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"],
                presetMinimums: c.presetMinimums ?? [18, 26, 36],
                presetMaximums: c.presetMaximums ?? [25, 35, 50],
                minimumLabel: c.minimumLabel ?? "Minimum age",
                maximumLabel: c.maximumLabel ?? "Maximum age",
                minimumPlaceholder: c.minimumPlaceholder ?? "18",
                maximumPlaceholder: c.maximumPlaceholder ?? "24",
                selectedOption: c.selectedOption ?? "Any age",
                minimum: c.minimum ?? "",
                maximum: c.maximum ?? "",
                loadedMinimum: c.loadedMinimum ?? "",
                loadedMaximum: c.loadedMaximum ?? "",
                focusedInput: c.focusedInput ?? "",
                saving: c.saving ?? false
            )
        )
        // The canvas: devices[0]'s width (iphone-16-pro-max, 440pt) × the linked frame's height.
        if let height = c.__frameHeight {
            return AnyView(screen.frame(width: 440, height: CGFloat(height), alignment: .top))
        }
        return AnyView(screen.frame(width: 440))
    case "screen.2.0.edit-text-multi-field":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.edit-text-multi-field: missing state.component")
        }
        // A missing field takes this build's `clean` sample (§2's Group description content table;
        // the label is OQ-edit-text-multi-field-1's proposed default).
        let screen = UI2Preview.EditTextMultiFieldScreen(
            state: .init(
                title: c.title ?? "Description",
                description: c.description ?? "The group description is used to help others understand the purpose of your group at a glance.",
                label: c.label ?? "Group description",
                placeholder: c.placeholder ?? "",
                text: c.text ?? "A group designed for young men who are out of college and are beginning their professional journey",
                loadedValue: c.loadedValue ?? "A group designed for young men who are out of college and are beginning their professional journey",
                focused: c.focused ?? false,
                saving: c.saving ?? false,
                promptCopy: c.promptCopy ?? "If you need help writing a description for your group, MakeReady AI can analyze your content and provide suggestions.",
                aiState: c.aiState ?? "prompt",
                suggestions: c.suggestions ?? []
            )
        )
        // The canvas: devices[0]'s width (iphone-16-pro-max, 440pt) × the linked frame's height.
        if let height = c.__frameHeight {
            return AnyView(screen.frame(width: 440, height: CGFloat(height), alignment: .top))
        }
        return AnyView(screen.frame(width: 440))
    case "component.ui2.C-032":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-032: missing state.component")
        }
        // C-032 §4: `title`, `author` and `createdLabel` are required (no contract default), so a
        // nil is a fixture bug. `onMenu` has R-03's no-op default and no render effect.
        guard let ui2C032Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-032: props.title is required")
        }
        guard let ui2C032Author = c.author else {
            throw ViewRegistryError.unknownView("component.ui2.C-032: props.author is required")
        }
        guard let ui2C032Created = c.createdLabel else {
            throw ViewRegistryError.unknownView("component.ui2.C-032: props.createdLabel is required")
        }
        return declareCase(
            UI2Preview.FollowedProgramHeader(title: ui2C032Title, author: ui2C032Author, createdLabel: ui2C032Created),
            // C-032 §2: "At the designed width of 408, the call site's `space-page-margin` inset
            // sits outside this row" — the master width, margin and ground live here (R-16).
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-054":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-054: missing state.component")
        }
        // C-054 §4: `title`, `progress`, `progressLabel` and `metadata` are required (no contract
        // default), so a nil is a fixture bug. `imageURL` / `initials` default to nil; `onTap`
        // has R-03's no-op default and no render effect.
        guard let ui2C054Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-054: props.title is required")
        }
        guard let ui2C054Progress = c.progress else {
            throw ViewRegistryError.unknownView("component.ui2.C-054: props.progress is required")
        }
        guard let ui2C054ProgressLabel = c.progressLabel else {
            throw ViewRegistryError.unknownView("component.ui2.C-054: props.progressLabel is required")
        }
        guard let ui2C054Metadata = c.metadata else {
            throw ViewRegistryError.unknownView("component.ui2.C-054: props.metadata is required (may be [])")
        }
        // Each entry is a C-043 MetaChip's own props. C-054 §3 spells them with C-043's RULED
        // names — `state: accent` (OQ-C-043-5) and `labelPosition: leading | trailing`
        // (OQ-C-043-1), which C-043 §4 and its build carry since 2026-10-24; `purple` is still
        // read as `accent` for older fixtures. An unrecognised value throws.
        var ui2C054Chips: [UI2Preview.AvatarProgressRow.Chip] = []
        for (index, item) in ui2C054Metadata.enumerated() {
            guard let value = item.value else {
                throw ViewRegistryError.unknownView("component.ui2.C-054: metadata[\(index)].value is required")
            }
            let state: UI2Preview.MetaChip.State
            switch item.state ?? "default" {
            case "accent", "purple": state = .accent
            case "default": state = .default
            case "complete": state = .complete
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-054: metadata[\(index)].state must be default|accent|complete")
            }
            let labelPosition: UI2Preview.MetaChip.LabelPosition
            switch item.labelPosition ?? "trailing" {
            case "trailing": labelPosition = .trailing
            case "leading": labelPosition = .leading
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-054: metadata[\(index)].labelPosition must be leading|trailing")
            }
            ui2C054Chips.append(.init(value: value, label: item.label, state: state, labelPosition: labelPosition))
        }
        // Seed the photo synchronously so the snapshot's single layout pass can render it —
        // same mechanism and same reason as the C-033 / C-038 cases above.
        let ui2C054ImageURL = c.imageURL.flatMap(URL.init(string:))
        if let photoURL = ui2C054ImageURL, photoURL.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        return declareCase(
            UI2Preview.AvatarProgressRow(
                title: ui2C054Title,
                imageURL: ui2C054ImageURL,
                initials: c.initials,
                progress: ui2C054Progress,
                progressLabel: ui2C054ProgressLabel,
                metadata: ui2C054Chips
            ),
            // C-054 §1 deviation 3: "the row fills the width its host gives it (R-16). 408 is the
            // sheet's sample" — the master width, margin and ground live here.
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-060":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-060: missing state.component")
        }
        // C-060 §4: every prop Required (R-07) — a missing one is a fixture bug, not a value to guess.
        guard let ui2C060Month = c.month else {
            throw ViewRegistryError.unknownView("component.ui2.C-060: props.month is required")
        }
        guard let ui2C060Weekday = c.weekday else {
            throw ViewRegistryError.unknownView("component.ui2.C-060: props.weekday is required")
        }
        // `day` is a two-shape field (CaptureFixture.swift): C-060 §4 types it `String`.
        guard let ui2C060Day = c.day?.stringValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-060: props.day (String) is required")
        }
        return declareCase(
            UI2Preview.CalendarDateCard(month: ui2C060Month, weekday: ui2C060Weekday, day: ui2C060Day),
            // C-060 §1 deviation 4: "Width is the call site's (R-16); 96 is what every known call
            // site gives" — the master width, margin and ground live here.
            PreviewFrame(width: 96)
        )
    case "component.ui2.C-079":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-079: missing state.component")
        }
        // C-079 §4 `image: Image?` — the fixture names the screenshot by URL and this case
        // resolves it, playing the caller (R-04 / R-19: the view does no loading). Absent is
        // `nil`, the `empty` state. A URL that is present but unreadable is a fixture bug,
        // not a quiet fall-back to `empty`.
        var ui2C079Image: Image?
        if let raw = c.image {
            guard let url = URL(string: raw), let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else {
                throw ViewRegistryError.unknownView("component.ui2.C-079: props.image \"\(raw)\" is not a readable image URL")
            }
            ui2C079Image = Image(uiImage: uiImage)
        }
        return declareCase(
            UI2Preview.ActivityScreenshot(image: ui2C079Image),
            // C-079 §2: "The design instance is 112×244" — the master width, margin and
            // ground live here (R-16); the height follows from the width.
            PreviewFrame(width: 112)
        )
    case "component.ui2.C-067":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-067: missing state.component")
        }
        // §4: `glyph` and `label` are required (R-07), so a nil is a fixture bug. `tone`
        // defaults to `.standard`; `onTap` is a no-op in the view.
        guard let glyph = c.glyph else {
            throw ViewRegistryError.unknownView("component.ui2.C-067: missing props.glyph")
        }
        guard let label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-067: missing props.label")
        }
        let ui2C067Tone: UI2Preview.ActionMenuRow.Tone
        switch c.tone ?? "standard" {
        case "standard": ui2C067Tone = .standard
        case "destructive": ui2C067Tone = .destructive
        case let other:
            throw ViewRegistryError.unknownView("component.ui2.C-067: props.tone \"\(other)\" must be standard|destructive")
        }
        return declareCase(
            UI2Preview.ActionMenuRow(glyph: glyph, label: label, tone: ui2C067Tone),
            // C-067 §1: the symbol is 369×56 — the master width; margin and ground live
            // here (R-16).
            PreviewFrame(width: 369)
        )
    case "component.ui2.C-080":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-080: missing state.component")
        }
        // C-080 §4: `glyph`, `title` and `description` are required (R-07) — a nil is a
        // fixture bug. `glyph` is a glyph-library name; an unknown one is a fixture bug too.
        // `onTap` is a no-op in the view. All three reuse existing fields under §4's own names.
        guard let ui2C080GlyphRaw = c.glyph else {
            throw ViewRegistryError.unknownView("component.ui2.C-080: missing props.glyph")
        }
        guard let ui2C080Glyph = UI2Preview.GlyphName(rawValue: ui2C080GlyphRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-080: props.glyph \"\(ui2C080GlyphRaw)\" is not a library glyph")
        }
        guard let ui2C080Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-080: missing props.title")
        }
        guard let ui2C080Description = c.description else {
            throw ViewRegistryError.unknownView("component.ui2.C-080: missing props.description")
        }
        return declareCase(
            UI2Preview.ActivityTypeCard(
                glyph: ui2C080Glyph,
                title: ui2C080Title,
                description: ui2C080Description
            ),
            // C-080 §2: "Designed at 200×180 in a two-column grid" — the master width; the
            // height follows from it. Margin and ground live here (R-16).
            PreviewFrame(width: 200)
        )
    case "screen.2.0.home-dashboard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.home-dashboard: missing state.component")
        }
        // A missing field takes this build's `populated` sample (the frozen frame `default`),
        // single-sourced on the screen's State so the props, the #Preview blocks and this case
        // cannot drift apart.
        let sample = UI2Preview.HomeDashboardScreen.State.populated
        // C-033's avatars: the fixture names each photo by URL and the harness resolves the
        // bytes (the same seam the C-033 case uses) — the view itself performs no network.
        for photo in c.groupPhotoURLs ?? sample.groupPhotoURLs {
            if let photoURL = URL(string: photo), photoURL.scheme?.hasPrefix("http") == true,
               UI2Preview.Ui2ImageCache.shared.image(for: photoURL) == nil,
               let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
                UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
            }
        }
        // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
        // max(its height, the content's length), under the top safe area — the bare screen here.
        return AnyView(UI2Preview.HomeDashboardScreen(
            state: .init(
                metricCount: c.metricCount ?? sample.metricCount,
                kpiTitles: c.kpiTitles ?? sample.kpiTitles,
                kpiValues: c.kpiValues ?? sample.kpiValues,
                kpiTrendDirections: c.kpiTrendDirections ?? sample.kpiTrendDirections,
                kpiTrendPolarities: c.kpiTrendPolarities ?? sample.kpiTrendPolarities,
                kpiTrendLabels: c.kpiTrendLabels ?? sample.kpiTrendLabels,
                kpiAverageLabels: c.kpiAverageLabels ?? sample.kpiAverageLabels,
                kpiSeries: c.kpiSeries ?? sample.kpiSeries,
                dayMonths: c.dayMonths ?? sample.dayMonths,
                dayWeekdays: c.dayWeekdays ?? sample.dayWeekdays,
                dayNumbers: c.dayNumbers ?? sample.dayNumbers,
                dayDateStates: c.dayDateStates ?? sample.dayDateStates,
                daySeries: c.daySeries ?? sample.daySeries,
                dayLine1s: c.dayLine1s ?? sample.dayLine1s,
                dayLine2s: c.dayLine2s ?? sample.dayLine2s,
                dayDetailsStates: c.dayDetailsStates ?? sample.dayDetailsStates,
                dayDates: c.dayDates ?? sample.dayDates,
                chartDates: c.chartDates ?? sample.chartDates,
                chartScheduled: c.chartScheduled ?? sample.chartScheduled,
                chartCompleted: c.chartCompleted ?? sample.chartCompleted,
                chartWindowStart: c.chartWindowStart ?? sample.chartWindowStart,
                chartWindowEnd: c.chartWindowEnd ?? sample.chartWindowEnd,
                chartToday: c.chartToday ?? sample.chartToday,
                sessionRange: c.sessionRange ?? sample.sessionRange,
                hourValues: c.hourValues ?? sample.hourValues,
                centerValue: c.centerValue ?? sample.centerValue,
                centerUnit: c.centerUnit ?? sample.centerUnit,
                centerCaption: c.centerCaption ?? sample.centerCaption,
                bins: c.bins ?? sample.bins,
                sessionTickValues: c.sessionTickValues ?? sample.sessionTickValues,
                sessionTickUnits: c.sessionTickUnits ?? sample.sessionTickUnits,
                activeCount: c.activeCount ?? sample.activeCount,
                engagementPercent: c.engagementPercent ?? sample.engagementPercent,
                engagementLabel: c.engagementLabel ?? sample.engagementLabel,
                engagementCount: c.engagementCount ?? sample.engagementCount,
                engagementProgress: c.engagementProgress ?? sample.engagementProgress,
                engagementSubtitle: c.engagementSubtitle ?? sample.engagementSubtitle,
                engagementColor: c.engagementColor ?? sample.engagementColor,
                followedCount: c.followedCount ?? sample.followedCount,
                programTitles: c.programTitles ?? sample.programTitles,
                programAuthors: c.programAuthors ?? sample.programAuthors,
                programCreatedLabels: c.programCreatedLabels ?? sample.programCreatedLabels,
                groupProgramIndices: c.groupProgramIndices ?? sample.groupProgramIndices,
                groupTitles: c.groupTitles ?? sample.groupTitles,
                groupPhotoURLs: c.groupPhotoURLs ?? sample.groupPhotoURLs,
                groupMembers: c.groupMembers ?? sample.groupMembers,
                groupPercents: c.groupPercents ?? sample.groupPercents,
                groupColors: c.groupColors ?? sample.groupColors,
                groupShowLinks: c.groupShowLinks ?? sample.groupShowLinks
            )
        ))
    case "component.ui2.C-037":
        // Out of line to keep buildCaptureView's Debug stack frame under the thread limit
        // (moved 2026-09-30 when the C-085 case overflowed it; body unchanged).
        return try buildUI2C037(fixture)
    case "component.ui2.C-061":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-061: missing state.component")
        }
        // C-061 §4: `active` and `label` are required with no default (R-07) — a nil is a
        // fixture bug, not a value to guess.
        guard let ui2C061Active = c.active else {
            throw ViewRegistryError.unknownView("component.ui2.C-061: props.active is required")
        }
        guard let ui2C061Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-061: props.label is required")
        }
        return declareCase(
            UI2Preview.ActivitySlide(active: ui2C061Active, label: ui2C061Label),
            // C-061 §2: "Fixed 33×44, its intrinsic size. The host places it and does not
            // stretch it." — no master width; margin and ground live here (R-16).
            PreviewFrame(intrinsic: true)
        )
    case "screen.2.0.create-study-program":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.create-study-program: missing state.component")
        }
        // A missing field takes this build's `empty` sample (the preview linked to the frozen
        // frame `default`), single-sourced on the screen's State.
        let sample = UI2Preview.CreateStudyProgramScreen.State.empty
        // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
        // max(its height, the content's length), under the top safe area — the bare screen here.
        return AnyView(UI2Preview.CreateStudyProgramScreen(
            state: .init(
                text: c.text ?? sample.text,
                creating: c.creating ?? sample.creating,
                errorMessage: c.errorMessage ?? sample.errorMessage
            )
        ))
    case "screen.2.0.create-group":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.create-group: missing state.component")
        }
        // A missing field takes this build's `empty` sample (the preview linked to the frozen
        // frame `default`), single-sourced on the screen's State.
        let sample = UI2Preview.CreateGroupScreen.State.empty
        // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
        return AnyView(UI2Preview.CreateGroupScreen(
            state: .init(
                text: c.text ?? sample.text,
                focused: c.focused ?? sample.focused,
                creating: c.creating ?? sample.creating
            )
        ))
    case "screen.2.0.invite-member":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.invite-member: missing state.component")
        }
        // A missing field takes this build's `name-empty` sample (§3's initial state),
        // single-sourced on the screen's State.
        let sample = UI2Preview.InviteMemberScreen.State.nameEmpty
        // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
        return AnyView(UI2Preview.InviteMemberScreen(
            state: .init(
                step: c.step ?? sample.step,
                inviteeName: c.inviteeName ?? sample.inviteeName,
                digits: c.digits ?? sample.digits,
                sending: c.sending ?? sample.sending
            )
        ))
    default:
        return nil
    }
}

/// Part 8 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart8(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ui2.C-065":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-065: missing state.component")
        }
        // C-065 §4: `dateLabel` and `text` are required (R-07), so a nil is a fixture bug.
        // `highlight` defaults to nil and `tone` to `.neutral`.
        guard let dateLabel = c.dateLabel else {
            throw ViewRegistryError.unknownView("component.ui2.C-065: missing props.dateLabel")
        }
        guard let text = c.text else {
            throw ViewRegistryError.unknownView("component.ui2.C-065: missing props.text")
        }
        let ui2C065Tone: UI2Preview.TimelineEventRow.Tone
        switch c.tone ?? "neutral" {
        case "neutral": ui2C065Tone = .neutral
        case "positive": ui2C065Tone = .positive
        case "accent": ui2C065Tone = .accent
        case let other:
            throw ViewRegistryError.unknownView("component.ui2.C-065: props.tone \"\(other)\" must be neutral|positive|accent")
        }
        return declareCase(
            UI2Preview.TimelineEventRow(dateLabel: dateLabel, text: text, highlight: c.highlight, tone: ui2C065Tone),
            // C-065 §2: the symbols are 408 wide (440 − 2 × `space-page-margin`) — the master
            // width; margin and ground live here (R-16).
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-082":
        guard fixture.state?.component != nil else {
            throw ViewRegistryError.unknownView("component.ui2.C-082: missing state.component")
        }
        // C-082 §4 has exactly one prop, `onClose`, which is interaction-bearing and defaulted
        // to a no-op in the view — so each state's prop bag is authored empty and nothing on
        // `c` is read. §3 `pressed` is ephemeral (R-02, OQ-C-036-8) and has no prop to set.
        return declareCase(
            UI2Preview.ModalCloseButton(),
            // No master width: §2 fixes the control at 44×44 and the host positions it,
            // so the call site adds only the page margin and the ground (R-16).
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-055":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-055: missing state.component")
        }
        // C-055 §4: all three props are required (R-07) — a nil is a fixture bug. Each row's
        // `label`, `progress` and `countLabel` are required too. `Row.color` and `mode` are
        // OQ-C-055-001 additions §4 does not carry yet, so the fixture cannot set them and
        // they take their defaults (palette colour, `.isolated`).
        guard let ui2C055ValueTitle = c.valueColumnTitle else {
            throw ViewRegistryError.unknownView("component.ui2.C-055: props.valueColumnTitle is required")
        }
        guard let ui2C055CountTitle = c.countColumnTitle else {
            throw ViewRegistryError.unknownView("component.ui2.C-055: props.countColumnTitle is required")
        }
        guard let ui2C055RawRows = c.rows else {
            throw ViewRegistryError.unknownView("component.ui2.C-055: props.rows is required (may be [])")
        }
        var ui2C055Rows: [UI2Preview.CategoryBarTable.Row] = []
        for (index, row) in ui2C055RawRows.enumerated() {
            guard let label = row.label, let progress = row.progress, let countLabel = row.countLabel else {
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-055: rows[\(index)] needs label, progress and countLabel")
            }
            ui2C055Rows.append(.init(label: label, progress: progress, countLabel: countLabel))
        }
        return declareCase(
            UI2Preview.CategoryBarTable(
                valueColumnTitle: ui2C055ValueTitle,
                countColumnTitle: ui2C055CountTitle,
                rows: ui2C055Rows
            ),
            // C-055 §2: "Width = the host's (R-16)"; 408 is the source frame's width.
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-059":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-059: missing state.component")
        }
        // C-059 §4: `state`, `title`, `progress` and `metaChips` are required (no contract
        // default), so a nil is a fixture bug. `description`, `caption` and `cover` default to nil;
        // `onTap` is §4's no-op default (the initializer without it) — no render effect.
        guard let ui2C059State = c.state.flatMap(UI2Preview.StudyProgramRow.State.init(rawValue:)) else {
            throw ViewRegistryError.unknownView("component.ui2.C-059: props.state must be Condensed|Progress|Complete|Enrolled|Program")
        }
        guard let ui2C059Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-059: props.title is required")
        }
        guard let ui2C059Progress = c.progress else {
            throw ViewRegistryError.unknownView("component.ui2.C-059: props.progress is required")
        }
        guard let ui2C059MetaChips = c.metaChips else {
            throw ViewRegistryError.unknownView("component.ui2.C-059: props.metaChips is required (may be [])")
        }
        // Each entry is a C-043 MetaChip's own §4 props, spelled as C-043 §4 spells them
        // (`state`, and `align` → C-043 `labelPosition`) with C-043's defaults.
        var ui2C059Chips: [UI2Preview.StudyProgramRow.Chip] = []
        for (index, item) in ui2C059MetaChips.enumerated() {
            guard let value = item.value else {
                throw ViewRegistryError.unknownView("component.ui2.C-059: metaChips[\(index)].value is required")
            }
            // C-043 §4 renamed `purple` → `accent` (OQ-C-043-5) and `align: left|right` →
            // `labelPosition: trailing|leading` (OQ-C-043-1); this row's own §4 still spells the tuple
            // `align`, so both spellings are read.
            let state: UI2Preview.MetaChip.State
            switch item.state ?? "default" {
            case "default": state = .default
            case "accent", "purple": state = .accent
            case "complete": state = .complete
            case "highlighted": state = .highlighted
            case "muted": state = .muted
            default:
                throw ViewRegistryError.unknownView(
                    "component.ui2.C-059: metaChips[\(index)].state must be default|accent|complete|highlighted|muted")
            }
            let align: UI2Preview.MetaChip.LabelPosition
            switch item.align ?? "left" {
            case "left", "trailing": align = .trailing
            case "right", "leading": align = .leading
            default:
                throw ViewRegistryError.unknownView("component.ui2.C-059: metaChips[\(index)].align must be left|right")
            }
            ui2C059Chips.append(.init(value: value, label: item.label, state: state, align: align))
        }
        // §4 `cover: Image?` — the fixture names the cover by URL and this case resolves it,
        // playing the caller (R-19 / R-32: the row does no loading). Absent is `nil`, the
        // `missing-cover` state; a URL that is present but unreadable is a fixture bug.
        var ui2C059Cover: Image?
        if let raw = c.cover {
            guard let url = URL(string: raw), let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else {
                throw ViewRegistryError.unknownView("component.ui2.C-059: props.cover \"\(raw)\" is not a readable image URL")
            }
            ui2C059Cover = Image(uiImage: uiImage)
        }
        return declareCase(
            UI2Preview.StudyProgramRow(
                state: ui2C059State,
                title: ui2C059Title,
                description: c.description,
                caption: c.caption,
                progress: ui2C059Progress,
                metaChips: ui2C059Chips,
                cover: ui2C059Cover
            ),
            // C-059 §2 Root: "fills the width it is given (designed at 408)" — the master
            // width, margin and ground live here (R-16).
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-063":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-063: missing state.component")
        }
        // C-063 §4: `header`, `title`, `metaLabel` and `slides` are required (R-07 — no
        // designed default), so a nil is a fixture bug. `progress` is `Double?` (nil = none).
        // `onOpen` / `onSelectSlide` are §4's no-op defaults — no render effect.
        let ui2C063Header: UI2Preview.LessonCard.Header
        if let numbered = c.header?.numbered, c.header?.linked == nil {
            ui2C063Header = .numbered(lessonNumber: numbered.lessonNumber)
        } else if let linked = c.header?.linked, c.header?.numbered == nil {
            ui2C063Header = .linked(label: linked.label)
        } else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-063: props.header needs exactly one of numbered{lessonNumber}|linked{label}")
        }
        guard let ui2C063Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-063: props.title is required")
        }
        guard let ui2C063MetaLabel = c.metaLabel else {
            throw ViewRegistryError.unknownView("component.ui2.C-063: props.metaLabel is required")
        }
        guard let ui2C063RawSlides = c.slides else {
            throw ViewRegistryError.unknownView("component.ui2.C-063: props.slides is required (may be [])")
        }
        // Each slide's `image` is named by URL and resolved here, playing the caller (R-19 /
        // R-32; the C-079 precedent). Absent is `nil` (C-079 `empty`); a URL that is present
        // but unreadable is a fixture bug.
        var ui2C063Slides: [UI2Preview.LessonCard.Slide] = []
        for (index, item) in ui2C063RawSlides.enumerated() {
            guard let label = item.label else {
                throw ViewRegistryError.unknownView("component.ui2.C-063: slides[\(index)].label is required")
            }
            var image: Image?
            if let raw = item.image {
                guard let url = URL(string: raw), let data = try? Data(contentsOf: url),
                      let uiImage = UIImage(data: data) else {
                    throw ViewRegistryError.unknownView(
                        "component.ui2.C-063: slides[\(index)].image \"\(raw)\" is not a readable image URL")
                }
                image = Image(uiImage: uiImage)
            }
            ui2C063Slides.append(.init(image: image, label: label))
        }
        return declareCase(
            UI2Preview.LessonCard(
                header: ui2C063Header,
                title: ui2C063Title,
                metaLabel: ui2C063MetaLabel,
                progress: c.progress,
                slides: ui2C063Slides
            ),
            // C-063 §1 dev 3: the card is full-bleed at the host's width — the frame-local
            // source is 440 wide, so the master width is 440 with no horizontal margin (its
            // insets are internal). §1 dev 2: the source's py16 is the host's, so it lives
            // here as vertical padding only (R-16).
            PreviewFrame(width: 440, marginEdges: .vertical)
        )
    case "component.ui2.C-081":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-081: missing state.component")
        }
        // C-081 §4: `slides` and `activeID` are required (R-07 — no designed default), so a
        // missing `slides` is a fixture bug; `activeID` absent is its own designed value, nil
        // ("none is outlined"). `onSelectSlide` / `onAdd` are §4's no-op defaults.
        guard let ui2C081RawSlides = c.slides else {
            throw ViewRegistryError.unknownView("component.ui2.C-081: props.slides is required (may be [])")
        }
        // Each slide's `image` is named by URL and resolved here, playing the caller (R-19 /
        // R-32; the C-079 / C-063 precedent). Absent is `nil` (→ C-061); a URL that is present
        // but unreadable is a fixture bug.
        var ui2C081Slides: [UI2Preview.ActivityNavBar.Slide] = []
        for (index, item) in ui2C081RawSlides.enumerated() {
            guard let id = item.id else {
                throw ViewRegistryError.unknownView("component.ui2.C-081: slides[\(index)].id is required")
            }
            guard let label = item.label else {
                throw ViewRegistryError.unknownView("component.ui2.C-081: slides[\(index)].label is required")
            }
            var image: Image?
            if let raw = item.image {
                guard let url = URL(string: raw), let data = try? Data(contentsOf: url),
                      let uiImage = UIImage(data: data) else {
                    throw ViewRegistryError.unknownView(
                        "component.ui2.C-081: slides[\(index)].image \"\(raw)\" is not a readable image URL")
                }
                image = Image(uiImage: uiImage)
            }
            ui2C081Slides.append(.init(id: id, image: image, label: label))
        }
        return AnyView(
            UI2Preview.ActivityNavBar(slides: ui2C081Slides, activeID: c.activeID)
            // C-081 §1: symbol 440×76 — the master width. The four-side 16 inset is the bar's
            // own (§2 Padding), so the call site adds no margin, only the ground (R-16).
            .frame(width: 440)
            .frame(maxWidth: .infinity)
            .background(UI2Preview.Token.layoutBackground)
        )
    case "screen.2.0.members-profile":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.members-profile: missing state.component")
        }
        // A missing field takes this build's `populated` sample (the preview linked to the frozen
        // frame `default`), single-sourced on the screen's State.
        let sample = UI2Preview.MembersProfileScreen.State.populated
        // C-038 / C-037 photos and C-059 covers: the fixture names each image by URL and the
        // harness resolves the bytes into the preview module's cache (the home-dashboard seam) —
        // the view itself performs no network.
        let ui2MembersProfileImages = [c.avatarURL ?? sample.avatarURL]
            + (c.groupPhotoURLs ?? sample.groupPhotoURLs)
            + (c.programCoverURLs ?? sample.programCoverURLs)
        for raw in ui2MembersProfileImages {
            if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
               UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
               let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
            }
        }
        // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
        // max(its height, the content's length), under the top safe area — the bare screen here.
        return AnyView(UI2Preview.MembersProfileScreen(
            state: .init(
                memberName: c.memberName ?? sample.memberName,
                email: c.email ?? sample.email,
                avatarURL: c.avatarURL ?? sample.avatarURL,
                initials: c.initials ?? sample.initials,
                age: c.age ?? sample.age,
                role: c.role ?? sample.role,
                birthday: c.birthday ?? sample.birthday,
                joined: c.joined ?? sample.joined,
                organization: c.organization ?? sample.organization,
                phone: c.phone ?? sample.phone,
                phoneVerified: c.phoneVerified ?? sample.phoneVerified,
                emailVerified: c.emailVerified ?? sample.emailVerified,
                gender: c.gender ?? sample.gender,
                address: c.address ?? sample.address,
                emergencyContact: c.emergencyContact ?? sample.emergencyContact,
                dayMonths: c.dayMonths ?? sample.dayMonths,
                dayWeekdays: c.dayWeekdays ?? sample.dayWeekdays,
                dayNumbers: c.dayNumbers ?? sample.dayNumbers,
                dayDateStates: c.dayDateStates ?? sample.dayDateStates,
                daySeries: c.daySeries ?? sample.daySeries,
                dayLine1s: c.dayLine1s ?? sample.dayLine1s,
                dayLine2s: c.dayLine2s ?? sample.dayLine2s,
                dayDetailsStates: c.dayDetailsStates ?? sample.dayDetailsStates,
                groupTitles: c.groupTitles ?? sample.groupTitles,
                groupPhotoURLs: c.groupPhotoURLs ?? sample.groupPhotoURLs,
                groupLeaders: c.groupLeaders ?? sample.groupLeaders,
                groupJoinedDates: c.groupJoinedDates ?? sample.groupJoinedDates,
                programTitles: c.programTitles ?? sample.programTitles,
                programStates: c.programStates ?? sample.programStates,
                programProgress: c.programProgress ?? sample.programProgress,
                programCompleteCounts: c.programCompleteCounts ?? sample.programCompleteCounts,
                programHours: c.programHours ?? sample.programHours,
                programCoverURLs: c.programCoverURLs ?? sample.programCoverURLs
            )
        ))
    case "component.ui2.C-036":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-036: missing state.component")
        }
        // §4 `options` is required (R-07) and IS the component, so a nil is a fixture bug.
        // `options` decodes the object shape here (`.items`) — see CaptureStringsOrOptions.
        guard let ui2C036Options = c.options?.items else {
            throw ViewRegistryError.unknownView("component.ui2.C-036: props.options ([Option]) is required")
        }
        // OQ-C-036-009's selection API: `selectionMode` and `selectedIDs` are both required
        // (R-07); an empty `selectedIDs` is legal (a plain option menu with no checkmark).
        let ui2C036Mode: UI2Preview.FilterMenuOverlay.SelectionMode
        switch c.selectionMode {
        case "single": ui2C036Mode = .single
        case "multiple": ui2C036Mode = .multiple
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-036: props.selectionMode must be single|multiple")
        }
        guard let ui2C036Selected = c.selectedIDs else {
            throw ViewRegistryError.unknownView("component.ui2.C-036: props.selectedIDs is required (may be [])")
        }
        let ui2C036View = UI2Preview.FilterMenuOverlay(
            options: ui2C036Options.map {
                UI2Preview.FilterMenuOverlay.Option(id: $0.id, label: $0.label, glyph: $0.glyph)
            },
            selectionMode: ui2C036Mode,
            selectedIDs: Set(ui2C036Selected)
        )
        // The Presented state (§3) is the same view through the §4 modifier; the other states
        // are the bare view, which paints no dim (OQ-C-036-4).
        let ui2C036Content: AnyView = c.isPresented.map {
            AnyView(ui2C036View.filterMenuPresentation(isPresented: $0))
        } ?? AnyView(ui2C036View)
        return AnyView(
            ui2C036Content
                // The frozen frame is 440×893 (§1). A component renders with no safe area, so
                // Figma's list top y=53 — OQ-C-036-6: "Figma's 53 stands in for the status
                // bar" — is supplied here as the top safe-area inset, and the zero bottom inset
                // puts the close button's bottom at `space-section-gap` (y=817, as drawn).
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 53) }
                .frame(width: 440, height: 893)
                .frame(maxWidth: .infinity)
                .background(UI2Preview.Token.layoutBackground)  // OQ-PB-2 default
        )
    case "screen.2.0.members-home":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.members-home: missing state.component")
        }
        // A missing field takes this build's `populated` sample (the preview linked to the frozen
        // frame `default`), single-sourced on the screen's State.
        let sample = UI2Preview.MembersHomeScreen.State.populated
        // C-038 photos inside C-037: the fixture names each image by URL and the harness resolves
        // the bytes into the preview module's cache (the home-dashboard seam) — the view itself
        // performs no network.
        for raw in c.memberPhotoURLs ?? sample.memberPhotoURLs {
            if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
               UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
               let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
            }
        }
        // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
        // max(its height, the content's length), under the top safe area — the bare screen here.
        return AnyView(UI2Preview.MembersHomeScreen(
            state: .init(
                searchText: c.searchText ?? sample.searchText,
                groupFilterLabel: c.groupFilterLabel ?? sample.groupFilterLabel,
                leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
                groupOptions: c.groupOptions ?? sample.groupOptions,
                leaderOptions: c.leaderOptions ?? sample.leaderOptions,
                memberNames: c.memberNames ?? sample.memberNames,
                memberPhotoURLs: c.memberPhotoURLs ?? sample.memberPhotoURLs,
                memberJoinedLabels: c.memberJoinedLabels ?? sample.memberJoinedLabels,
                memberGroupCounts: c.memberGroupCounts ?? sample.memberGroupCounts
            )
        ))
    case "screen.2.0.groups-home":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("screen.2.0.groups-home: missing state.component")
        }
        // A missing field takes this build's `populated` sample (the preview linked to the frozen
        // frame `default`), single-sourced on the screen's State.
        let sample = UI2Preview.GroupsHomeScreen.State.populated
        // C-038 photos inside C-037: the fixture names each image by URL and the harness resolves
        // the bytes into the preview module's cache (the home-dashboard seam) — the view itself
        // performs no network.
        for raw in c.groupPhotoURLs ?? sample.groupPhotoURLs {
            if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
               UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
               let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
            }
        }
        // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
        // max(its height, the content's length), under the top safe area — the bare screen here.
        return AnyView(UI2Preview.GroupsHomeScreen(
            state: .init(
                searchText: c.searchText ?? sample.searchText,
                orgFilterVisible: c.orgFilterVisible ?? sample.orgFilterVisible,
                orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
                leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
                orgOptions: c.orgOptions ?? sample.orgOptions,
                leaderOptions: c.leaderOptions ?? sample.leaderOptions,
                groupNames: c.groupNames ?? sample.groupNames,
                groupPhotoURLs: c.groupPhotoURLs ?? sample.groupPhotoURLs,
                groupLeaderNames: c.groupLeaderNames ?? sample.groupLeaderNames,
                groupMemberCounts: c.groupMemberCounts ?? sample.groupMemberCounts
            )
        ))
    case "component.ui2.C-058":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-058: missing state.component")
        }
        // C-058 §4: `groupName` and `leaderName` are required (no contract default), so a nil is a
        // fixture bug. `imageURL` / `initials` default to nil; `onOpen` has R-03's no-op default
        // and no render effect.
        guard let ui2C058GroupName = c.groupName else {
            throw ViewRegistryError.unknownView("component.ui2.C-058: props.groupName is required")
        }
        guard let ui2C058LeaderName = c.leaderName else {
            throw ViewRegistryError.unknownView("component.ui2.C-058: props.leaderName is required")
        }
        // Seed the photo synchronously so the snapshot's single layout pass can render it —
        // same mechanism and same reason as the C-033 / C-038 / C-054 cases above.
        let ui2C058ImageURL = c.imageURL.flatMap(URL.init(string:))
        if let photoURL = ui2C058ImageURL, photoURL.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        return declareCase(
            UI2Preview.GroupSectionHeader(
                groupName: ui2C058GroupName,
                leaderName: ui2C058LeaderName,
                imageURL: ui2C058ImageURL,
                initials: c.initials
            ),
            // C-058 §2: the row "fills the width it is given (408 at design)" — the master width,
            // margin and ground live here (R-16).
            PreviewFrame(width: 408)
        )
    case "component.ui2.C-083":
        // Out of line on purpose: buildCaptureView's Debug stack frame is at the thread's
        // limit, and one more inline case overflows it (crash in the C-083 build, 2026-09-30).
        return try buildUI2C083(fixture)
    case "component.ui2.C-085":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C085(fixture)
    case "screen.2.0.activity-new":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenActivityNew(fixture)
    case "component.ui2.C-087":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C087(fixture)
    case "screen.2.0.study-program-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenStudyProgramHome(fixture)
    case "screen.2.0.invite-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenInviteHome(fixture)
    case "screen.2.0.enrollment-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentHome(fixture)
    case "screen.2.0.invites-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenInvitesHome(fixture)
    case "screen.2.0.groups-detail":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenGroupsDetail(fixture)
    case "screen.2.0.enrollments-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentsHome(fixture)
    case "screen.2.0.search-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenSearchHome(fixture)
    case "screen.2.0.activities-editor":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenActivitiesEditor(fixture)
    case "component.ui2.C-102":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C102(fixture)
    default:
        return nil
    }
}

/// Part 9 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart9(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ui2.C-105":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-105: missing state.component")
        }
        // C-105 §4 (R-07): `label` is required — a nil is a fixture bug, not a value to guess.
        // `leadingGlyph` / `trailingGlyph` default to nil (none on that side); `onTap` is the
        // view's no-op default. §3 `pressed` is ephemeral (R-02, OQ-C-105-002) and has no prop to
        // set, so it renders at rest, as C-102's and C-104's do.
        guard let ui2C105Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-105: props.label is required")
        }
        let ui2C105Leading = try c.leadingGlyph.map { raw -> UI2Preview.GlyphName in
            guard let name = UI2Preview.GlyphName(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-105: props.leadingGlyph \"\(raw)\" is not a library glyph")
            }
            return name
        }
        let ui2C105Trailing = try c.trailingGlyph.map { raw -> UI2Preview.GlyphName in
            guard let name = UI2Preview.GlyphName(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-105: props.trailingGlyph \"\(raw)\" is not a library glyph")
            }
            return name
        }
        return declareCase(
            UI2Preview.Button(label: ui2C105Label, leadingGlyph: ui2C105Leading, trailingGlyph: ui2C105Trailing),
            // No master width: §2 hugs its content at a fixed 36pt height and the host positions
            // it, so the call site adds only the page margin and the ground (R-16).
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-091":
        return try buildUI2C091(fixture)
    case "component.ui2.C-095":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-095: missing state.component")
        }
        // C-095 §4: `color` is required — a nil or unreadable hex is a fixture bug, not a value
        // to guess. `armed` defaults to false; `onTap` is the view's no-op default. Press
        // feedback is ephemeral (R-02) and renders at rest.
        guard let ui2C095Raw = c.color, let ui2C095Color = ui2C091Hex(ui2C095Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-095: props.color must be #rrggbb")
        }
        return declareCase(
            UI2Preview.ColorPickerWell(color: ui2C095Color, armed: c.armed ?? false),
            // §2: fixed 34×34, no master width — the well hugs its own disc.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-096":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-096: missing state.component")
        }
        // C-096 §4: `color` and `label` are required — a nil or unreadable hex is a fixture bug,
        // not a value to guess. `selected` defaults to false; `onTap` is the view's no-op
        // default. Press feedback is ephemeral (R-02) and renders at rest.
        guard let ui2C096Raw = c.color, let ui2C096Color = ui2C091Hex(ui2C096Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-096: props.color must be #rrggbb")
        }
        guard let ui2C096Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-096: props.label is required")
        }
        return declareCase(
            UI2Preview.ColorSwatch(
                color: ui2C096Color,
                label: ui2C096Label,
                selected: c.selected?.boolValue ?? false
            ),
            // §2: fixed 24×24, no master width — the swatch hugs its own tile.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-097":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-097: missing state.component")
        }
        // C-097 §4 (R-07): `pageCount` is required — a nil is a fixture bug, not a value to guess.
        // `page` defaults to 0 (the design's first dot active).
        guard let ui2C097PageCount = c.pageCount else {
            throw ViewRegistryError.unknownView("component.ui2.C-097: props.pageCount is required")
        }
        return declareCase(
            UI2Preview.PageIndicator(pageCount: ui2C097PageCount, page: c.page ?? 0),
            // §2 / §5: centred in the width its consumer hands it — C-094's 440pt panel, the
            // device width, so no page margin (the C-091 precedent).
            PreviewFrame(width: 440, margin: 0)
        )
    case "component.ui2.C-094":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-094: missing state.component")
        }
        // C-094 §4 (R-07): `currentColor` and `swatches` are required — a nil or unreadable hex
        // is a fixture bug, not a value to guess. `page` defaults to 0 (the design's first dot
        // active); the three callbacks are the view's no-op defaults.
        guard let ui2C094Raw = c.currentColor, let ui2C094Color = ui2C091Hex(ui2C094Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-094: props.currentColor must be #rrggbb")
        }
        guard let ui2C094RawPages = c.swatches else {
            throw ViewRegistryError.unknownView("component.ui2.C-094: props.swatches is required")
        }
        let ui2C094Pages = try ui2C094RawPages.map { rawPage in
            try rawPage.map { swatch -> UI2Preview.TextColorPalette.NamedColor in
                guard let color = ui2C091Hex(swatch.color) else {
                    throw ViewRegistryError.unknownView("component.ui2.C-094: swatch \"\(swatch.name)\" color must be #rrggbb")
                }
                return .init(name: swatch.name, color: color)
            }
        }
        return declareCase(
            UI2Preview.TextColorPalette(currentColor: ui2C094Color, swatches: ui2C094Pages, page: c.page ?? 0),
            // §2: 440 × 66 — the panel fills the device width, so no page margin (the C-097 /
            // C-091 precedent).
            PreviewFrame(width: 440, margin: 0)
        )
    case "component.ui2.C-106":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-106: missing state.component")
        }
        // C-106 §4 (R-07): `items` (never empty) and `selectedID` are required — a nil is a fixture
        // bug. `onSelect` is the view's no-op default.
        guard let ui2C106Raw = c.items, !ui2C106Raw.isEmpty else {
            throw ViewRegistryError.unknownView("component.ui2.C-106: props.items is required and never empty")
        }
        guard let ui2C106Selected = c.selectedID else {
            throw ViewRegistryError.unknownView("component.ui2.C-106: props.selectedID is required")
        }
        let ui2C106Items: [UI2Preview.ChipStrip.Item] = try ui2C106Raw.enumerated().map { index, raw in
            guard let id = raw.id, let label = raw.label else {
                throw ViewRegistryError.unknownView("component.ui2.C-106: items[\(index)] needs id and label")
            }
            // `font` is C-092's value set, decoded exactly as C-092's and C-035's cases decode it.
            let font: UI2Preview.CanvasTextObject.Font?
            switch raw.font {
            case "poppins": font = .poppins
            case "sfPro": font = .sfPro
            case "georgia": font = .georgia
            case "typewriter": font = .typewriter
            case nil: font = nil
            default:
                throw ViewRegistryError.unknownView("component.ui2.C-106: items[\(index)].font must be poppins|sfPro|georgia|typewriter")
            }
            return .init(id: id, label: label, font: font)
        }
        // §2: the strip fills the width it is given and its 16pt insets are its own scroll-content
        // insets, so it is captured full-bleed (no horizontal page margin; the C-081 / C-094
        // precedent). `__frameWidth` (harness key) narrows it to reach §3 `overflow`.
        return declareCase(
            UI2Preview.ChipStrip(items: ui2C106Items, selectedID: ui2C106Selected),
            PreviewFrame(width: CGFloat(c.__frameWidth ?? 440), marginEdges: .vertical, alignment: .leading)
        )
    case "component.ui2.C-108":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-108: missing state.component")
        }
        // C-108 §4 (R-07): `key` is required — a nil is a fixture bug. The fixture spells it as
        // §3 does ("digit(1)", "delete"). `enabled` defaults to true (§4); `onTap` and
        // `onLongPress` are the view's no-op defaults. §3 `pressed` is ephemeral (R-02) and has
        // no prop to set, so `digit-pressed` renders the key at rest, as C-102's does.
        guard let ui2C108KeyRaw = c.key else {
            throw ViewRegistryError.unknownView("component.ui2.C-108: props.key is required")
        }
        let ui2C108Key: UI2Preview.KeypadKey.Key
        if ui2C108KeyRaw == "delete" {
            ui2C108Key = .delete
        } else if ui2C108KeyRaw.hasPrefix("digit("), ui2C108KeyRaw.hasSuffix(")"),
                  let digit = Int(ui2C108KeyRaw.dropFirst(6).dropLast()), (0...9).contains(digit) {
            ui2C108Key = .digit(digit)
        } else {
            throw ViewRegistryError.unknownView("component.ui2.C-108: props.key must be digit(0)…digit(9) | delete")
        }
        return declareCase(
            UI2Preview.KeypadKey(key: ui2C108Key, enabled: c.enabled ?? true),
            // No master width: §2 fixes the key at 64×64 and C-107 places it, so the call site
            // adds only the page margin and the ground (R-16).
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-107":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-107: missing state.component")
        }
        // C-107 §4: `enabled` and `deleteEnabled` default to true. `onDigit`, `onDelete` and
        // `onClear` are the view's no-op defaults.
        return declareCase(
            UI2Preview.NumberKeypad(enabled: c.enabled ?? true, deleteEnabled: c.deleteEnabled ?? true),
            // §2: the designed footprint is 320 wide, the master width. The keypad centres its 256pt
            // grid in that width (OQ-C-107-002), so the frame alone sets the 32pt side inset.
            PreviewFrame(width: 320)
        )
    case "component.ui2.C-109":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-109: missing state.component")
        }
        // C-109 §4 (R-07): `tone` and `animated` are both required — a nil is a fixture bug.
        guard let ui2C109Tone = c.tone.flatMap(UI2Preview.ConfirmationMark.Tone.init(rawValue:)) else {
            throw ViewRegistryError.unknownView("component.ui2.C-109: props.tone must be success|warning|error")
        }
        guard let ui2C109Animated = c.animated else {
            throw ViewRegistryError.unknownView("component.ui2.C-109: props.animated is required")
        }
        return declareCase(
            UI2Preview.ConfirmationMark(tone: ui2C109Tone, animated: ui2C109Animated),
            // §2: designed at 100×100 (invite-member's frame); width-driven and square (R-16).
            PreviewFrame(width: 100)
        )
    case "component.ui2.C-069":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-069: missing state.component")
        }
        // C-069 §4 (R-07): `label`, `expansion` and `active` are required — a nil is a fixture
        // bug. `hasAdd` defaults to true; `onTap` / `onAdd` are the view's no-op defaults. §3
        // `pressed` is ephemeral @State (R-02, OQ-C-069-003) with no prop to set, so it renders
        // at rest, as C-105's does.
        guard let ui2C069Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-069: props.label is required")
        }
        guard let ui2C069Expansion = c.expansion else {
            throw ViewRegistryError.unknownView("component.ui2.C-069: props.expansion is required")
        }
        guard let ui2C069Active = c.active else {
            throw ViewRegistryError.unknownView("component.ui2.C-069: props.active is required")
        }
        return declareCase(
            UI2Preview.NavTabButton(
                label: ui2C069Label,
                expansion: CGFloat(ui2C069Expansion),
                active: ui2C069Active,
                hasAdd: c.hasAdd ?? true
            ),
            // No master width: §2 hugs the label collapsed and is a fixed 124×96 card expanded.
            PreviewFrame(alignment: .leading, intrinsic: true)
        )
    case "component.ui2.C-110":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-110: missing state.component")
        }
        // C-110 §4 (R-07): `code` and `copied` are required — a nil is a fixture bug, not a value
        // to guess. `onCopy` is the view's no-op default. The glyph's pressed dim is ephemeral
        // @State (R-02, OQ-C-110-001) with no prop to set, so it renders at rest.
        guard let ui2C110Code = c.code else {
            throw ViewRegistryError.unknownView("component.ui2.C-110: props.code is required")
        }
        guard let ui2C110Copied = c.copied else {
            throw ViewRegistryError.unknownView("component.ui2.C-110: props.copied is required")
        }
        return declareCase(
            UI2Preview.CopyableCodeCard(code: ui2C110Code, copied: ui2C110Copied),
            // §2: designed at 408 wide (invite-qr's code card, 16,119 · 408×56); width-driven (R-16).
            PreviewFrame(width: 408)
        )
    case "screen.2.0.study-programs":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenStudyPrograms(fixture)
    case "component.ui2.C-111":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C111(fixture)
    case "screen.2.0.invite-qr":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenInviteQr(fixture)
    case "component.ui2.C-114":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-114: missing state.component")
        }
        // C-114 §4 (R-07): `hairline` is required — a nil is a fixture bug, not a value to guess.
        guard let ui2C114Hairline = c.hairline else {
            throw ViewRegistryError.unknownView("component.ui2.C-114: props.hairline is required")
        }
        return declareCase(
            UI2Preview.WeekdayHeader(hairline: ui2C114Hairline),
            // §2: the full screen width, no side margin (02-design §4.1) — the C-091 precedent.
            PreviewFrame(width: 440, margin: 0)
        )
    case "component.ui2.C-112":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-112: missing state.component")
        }
        // C-112 §4 (R-07): `eventTypes` is required — a nil is a fixture bug, not a value to guess.
        guard let ui2C112Raw = c.eventTypes else {
            throw ViewRegistryError.unknownView("component.ui2.C-112: props.eventTypes is required ([] renders nothing)")
        }
        let ui2C112Types = try ui2C112Raw.map { raw -> UI2Preview.EventIndicator.EventType in
            guard let type = UI2Preview.EventIndicator.EventType(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-112: props.eventTypes \"\(raw)\" must be lesson|meeting|online|deadline|social|other")
            }
            return type
        }
        return declareCase(
            UI2Preview.EventIndicator(eventTypes: ui2C112Types),
            // §2: sized by its count (5/14/22/30 × 4), centred by its parent — it hugs its content.
            PreviewFrame(intrinsic: true)
        )
    case "component.ui2.C-113":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-113: missing state.component")
        }
        // C-113 §4 (R-07): `date`, `today` and `eventTypes` are required — a nil is a fixture
        // bug, not a value to guess. `onTap` is the view's no-op default; the pressed circle is
        // ephemeral @State (R-02) with no prop to set, so it renders at rest.
        guard let ui2C113Raw = c.date?.string,
              let ui2C113Date = ui2C113DateFormatter.date(from: ui2C113Raw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-113: props.date is required (yyyy-MM-dd)")
        }
        guard let ui2C113Today = c.today?.boolValue else {
            throw ViewRegistryError.unknownView("component.ui2.C-113: props.today is required (Bool)")
        }
        guard let ui2C113TypesRaw = c.eventTypes else {
            throw ViewRegistryError.unknownView("component.ui2.C-113: props.eventTypes is required ([] = no indicator)")
        }
        let ui2C113Types = try ui2C113TypesRaw.map { raw -> UI2Preview.EventIndicator.EventType in
            guard let type = UI2Preview.EventIndicator.EventType(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-113: props.eventTypes \"\(raw)\" must be lesson|meeting|online|deadline|social|other")
            }
            return type
        }
        return declareCase(
            UI2Preview.MonthDayCell(date: ui2C113Date, today: ui2C113Today, eventTypes: ui2C113Types),
            // §2: colW × 69, colW = 440 / 7 in C-115 (§1 snapshot: "Columns are 440/7 = 62.86 pt").
            PreviewFrame(width: 440.0 / 7.0)
        )
    case "component.ui2.C-115":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C115(fixture)
    case "component.ui2.C-116":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-116: missing state.component")
        }
        // C-116 §4 (R-07): `week`, `selected` and `today` are required — a nil is a fixture bug,
        // not a value to guess. `onSelectDate` / `onNextWeek` / `onPreviousWeek` are the view's
        // no-op defaults; the pressed circle is ephemeral @State (R-02), so it renders at rest.
        guard let ui2C116WeekRaw = c.week,
              let ui2C116Week = ui2C113DateFormatter.date(from: String(ui2C116WeekRaw.prefix(10))) else {
            throw ViewRegistryError.unknownView("component.ui2.C-116: props.week is required (yyyy-MM-dd)")
        }
        guard let ui2C116SelectedRaw = c.selected?.stringValue,
              let ui2C116Selected = ui2C113DateFormatter.date(from: String(ui2C116SelectedRaw.prefix(10))) else {
            throw ViewRegistryError.unknownView("component.ui2.C-116: props.selected is required (yyyy-MM-dd)")
        }
        guard let ui2C116TodayRaw = c.today?.stringValue,
              let ui2C116Today = ui2C115DateTimeFormatter.date(from: ui2C116TodayRaw)
                ?? ui2C113DateFormatter.date(from: String(ui2C116TodayRaw.prefix(10))) else {
            throw ViewRegistryError.unknownView("component.ui2.C-116: props.today is required (yyyy-MM-ddTHH:mm:ss)")
        }
        return declareCase(
            UI2Preview.WeekStrip(week: ui2C116Week, selected: ui2C116Selected, today: ui2C116Today),
            // §2: "the full screen width … 7 equal columns of width / 7" — the C-114/C-115 precedent.
            PreviewFrame(width: 440, margin: 0)
        )
    case "component.ui2.C-117":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C117(fixture)
    case "component.ui2.C-118":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-118: missing state.component")
        }
        // C-118 §4 (R-07): `title` and `eventType` are required — a nil is a fixture bug, not a
        // value to guess. `onTap` is the view's no-op default; the pressed dim is ephemeral
        // (R-02), so it renders at rest.
        guard let ui2C118Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-118: props.title is required")
        }
        guard let ui2C118TypeRaw = c.eventType,
              let ui2C118Type = UI2Preview.EventIndicator.EventType(rawValue: ui2C118TypeRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-118: props.eventType is required (lesson|meeting|online|deadline|social|other)")
        }
        return declareCase(
            UI2Preview.AllDayEventChip(title: ui2C118Title, eventType: ui2C118Type),
            // §3 Preview frame "372×20": the C-120 all-day row's span (x 66 → trailing − 2); the
            // chip states its own 20 pt height.
            PreviewFrame(width: 372, alignment: .leading)
        )
    case "component.ui2.C-119":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-119: missing state.component")
        }
        // C-119 §4 (R-07): `label` is required — a nil is a fixture bug, not a value to guess.
        guard let ui2C119Label = c.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-119: props.label is required")
        }
        return declareCase(
            UI2Preview.NowIndicator(label: ui2C119Label),
            // §3 Preview frame "440×14": the full timeline width; the row states its own 14 pt
            // height. Edge to edge so x 60 is measured from the frame's leading edge.
            PreviewFrame(width: 440, margin: 0)
        )
    default:
        return nil
    }
}

/// Part 10 of `buildCaptureView` — nil when `fixture.view` is not one of its cases.
@MainActor @inline(never)
private func buildCaptureViewPart10(_ fixture: CaptureFixture, authManager: AuthManager) throws -> AnyView? {
    switch fixture.view {
    case "component.ui2.C-120":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-120: missing state.component")
        }
        // C-120 §4 (R-07): `timedEvents`, `allDayEvents`, `allDayExpanded` and `topMinute` are
        // required — a nil is a fixture bug, not a value to guess. `nowMinute` is `Int?` (nil =
        // not today's page). Every callback is the view's no-op default.
        guard let ui2C120TimedRaw = c.timedEvents else {
            throw ViewRegistryError.unknownView("component.ui2.C-120: props.timedEvents is required")
        }
        let ui2C120Timed = try ui2C120TimedRaw.map { e -> UI2Preview.DayTimeline.TimedEvent in
            guard let kind = UI2Preview.CalendarEventBlock.DetailKind(rawValue: e.detailKind) else {
                throw ViewRegistryError.unknownView("component.ui2.C-120: timedEvents[].detailKind must be location|online|group")
            }
            guard let type = UI2Preview.EventIndicator.EventType(rawValue: e.eventType) else {
                throw ViewRegistryError.unknownView("component.ui2.C-120: timedEvents[].eventType must be lesson|meeting|online|deadline|social|other")
            }
            return UI2Preview.DayTimeline.TimedEvent(
                id: e.id, title: e.title, detail: e.detail, detailKind: kind, eventType: type,
                recurring: e.recurring, startMinute: e.startMinute, endMinute: e.endMinute,
                timeRangeText: e.timeRangeText
            )
        }
        guard let ui2C120AllDayRaw = c.allDayEvents else {
            throw ViewRegistryError.unknownView("component.ui2.C-120: props.allDayEvents is required")
        }
        let ui2C120AllDay = try ui2C120AllDayRaw.map { e -> UI2Preview.DayTimeline.AllDayEvent in
            guard let type = UI2Preview.EventIndicator.EventType(rawValue: e.eventType) else {
                throw ViewRegistryError.unknownView("component.ui2.C-120: allDayEvents[].eventType must be lesson|meeting|online|deadline|social|other")
            }
            return UI2Preview.DayTimeline.AllDayEvent(id: e.id, title: e.title, eventType: type)
        }
        guard let ui2C120Expanded = c.allDayExpanded else {
            throw ViewRegistryError.unknownView("component.ui2.C-120: props.allDayExpanded is required")
        }
        guard let ui2C120Top = c.topMinute else {
            throw ViewRegistryError.unknownView("component.ui2.C-120: props.topMinute is required")
        }
        return declareCase(
            UI2Preview.DayTimeline(
                timedEvents: ui2C120Timed,
                allDayEvents: ui2C120AllDay,
                allDayExpanded: ui2C120Expanded,
                nowMinute: c.nowMinute,
                topMinute: ui2C120Top
            ),
            // §3 "Previews sample the axes (440×651 frames)": the day area under the subtitle
            // hairline, edge to edge so x 56/64/66 are measured from the frame's leading edge.
            PreviewFrame(width: 440, height: 651, margin: 0)
        )
    case "component.ui2.C-121":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: missing state.component")
        }
        // C-121 §4 (R-07): `title`, `detailKind`, `eventType`, `timing` and `past` are required —
        // a nil is a fixture bug, not a value to guess. `detail` defaults to nil (§4);
        // `startTime` / `endTime` are `String?` (`allDay` uses neither); `onTap` is the view's
        // no-op default and the pressed highlight is ephemeral (R-02), so it renders at rest.
        guard let ui2C121Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: props.title is required")
        }
        guard let ui2C121KindRaw = c.detailKind,
              let ui2C121Kind = UI2Preview.CalendarEventBlock.DetailKind(rawValue: ui2C121KindRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: props.detailKind is required (location|online|group)")
        }
        guard let ui2C121TypeRaw = c.eventType,
              let ui2C121Type = UI2Preview.EventIndicator.EventType(rawValue: ui2C121TypeRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: props.eventType is required (lesson|meeting|online|deadline|social|other)")
        }
        guard let ui2C121TimingRaw = c.timing,
              let ui2C121Timing = UI2Preview.CalendarEventRow.Timing(rawValue: ui2C121TimingRaw) else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: props.timing is required (timed|continues|ends|allDay)")
        }
        guard let ui2C121Past = c.past else {
            throw ViewRegistryError.unknownView("component.ui2.C-121: props.past is required")
        }
        return declareCase(
            UI2Preview.CalendarEventRow(
                title: ui2C121Title,
                detail: c.detail,
                detailKind: ui2C121Kind,
                eventType: ui2C121Type,
                timing: ui2C121Timing,
                startTime: c.startTime,
                endTime: c.endTime,
                past: ui2C121Past
            ),
            // §3 "preview frame 440×52": full screen width, edge to edge — the row carries its
            // own x 20 / trailing − 20 insets (§2), so the frame adds no margin.
            PreviewFrame(width: 440, margin: 0)
        )
    case "component.ui2.C-122":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-122: missing state.component")
        }
        // C-122 §4 (R-07): `title` and `message` are required — a nil is a fixture bug, not a
        // value to guess.
        guard let ui2C122Title = c.title else {
            throw ViewRegistryError.unknownView("component.ui2.C-122: props.title is required")
        }
        guard let ui2C122Message = c.message else {
            throw ViewRegistryError.unknownView("component.ui2.C-122: props.message is required")
        }
        return declareCase(
            UI2Preview.CalendarEmptyState(title: ui2C122Title, message: ui2C122Message),
            // §3 "preview frame 320 wide" — the frozen crop's width.
            PreviewFrame(width: 320)
        )
    case "component.ui2.C-128":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C128(fixture)
    case "component.ui2.C-126":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ui2.C-126: missing state.component")
        }
        // C-126 §4 (R-07): `value` ("HH:mm") is required — a nil is a fixture bug, not a value to
        // guess. `onChange` is the view's no-op default.
        guard let ui2C126Value = c.value else {
            throw ViewRegistryError.unknownView("component.ui2.C-126: props.value (HH:mm) is required")
        }
        return declareCase(
            UI2Preview.TimeDialPicker(value: ui2C126Value),
            // C-126 §2: the dial block is 357 wide (the labels overhang it); height is intrinsic.
            PreviewFrame(width: 357)
        )
    case "component.ui2.C-127":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C127(fixture)
    case "screen.2.0.calendar-home":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenCalendarHome(fixture)
    case "screen.2.0.enrollment-select-group":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectGroup(fixture)
    case "screen.2.0.enrollment-select-program":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectProgram(fixture)
    case "screen.2.0.enrollment-select-invite-time":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectInviteTime(fixture)
    case "screen.2.0.enrollment-select-sync":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectSync(fixture)
    case "screen.2.0.enrollment-select-access":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectAccess(fixture)
    case "screen.2.0.enrollment-select-schedule":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenEnrollmentSelectSchedule(fixture)
    case "component.ui2.C-125":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C125(fixture)
    case "component.ui2.C-123":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C123(fixture)
    case "component.ui2.C-124":
        // Out of line for the same stack-frame reason as C-083.
        return try buildUI2C124(fixture)
    case "screen.2.0.groups-enroll-program":
        // Out of line for the same stack-frame reason as C-083.
        return try buildScreenGroupsEnrollProgram(fixture)
    default:
        return nil
    }
}

/// `screen.2.0.calendar-home` — the calendar-home screen preview. See the case in
/// `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildScreenCalendarHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.calendar-home: missing state.component")
    }
    // A missing field takes this build's `month-current` sample (§3 state 1; the screen has no
    // frozen frame), single-sourced on the screen's State.
    let sample = UI2Preview.CalendarHomeScreen.State.monthCurrent
    // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
    return AnyView(UI2Preview.CalendarHomeScreen(
        state: .init(
            mode: c.mode ?? sample.mode,
            origin: c.origin ?? sample.origin,
            now: c.now ?? sample.now,
            topMonth: c.topMonth ?? sample.topMonth,
            selectedDate: c.selectedDate ?? sample.selectedDate,
            query: c.query ?? sample.query,
            focused: c.focused ?? sample.focused,
            loading: c.loading ?? sample.loading,
            searchFetching: c.searchFetching ?? sample.searchFetching,
            searchFailed: c.searchFailed ?? sample.searchFailed,
            eventDates: c.eventDates ?? sample.eventDates,
            eventTitles: c.eventTitles ?? sample.eventTitles,
            eventTypes: c.eventTypes ?? sample.eventTypes,
            eventStarts: c.eventStarts ?? sample.eventStarts,
            eventEnds: c.eventEnds ?? sample.eventEnds,
            eventLocations: c.eventLocations ?? sample.eventLocations,
            eventURLs: c.eventURLs ?? sample.eventURLs,
            eventGroups: c.eventGroups ?? sample.eventGroups,
            eventRecurring: c.eventRecurring ?? sample.eventRecurring
        )
    ))
}

/// `component.ui2.C-128` — C-128 DateRangePicker. See the case in `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildUI2C128(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: missing state.component")
    }
    // C-128 §4 (R-07): every value prop is required — a nil is a fixture bug, not a value to
    // guess — except `startDate`, whose nil IS "none chosen". The three callbacks are the view's
    // no-op defaults. Dates are yyyy-MM-dd in the device's time zone (the C-113 formatter), so a
    // start of day never shifts.
    func day(_ raw: String, _ prop: String) throws -> Date {
        guard let date = ui2C113DateFormatter.date(from: String(raw.prefix(10))) else {
            throw ViewRegistryError.unknownView("component.ui2.C-128: props.\(prop) \"\(raw)\" is not yyyy-MM-dd")
        }
        return date
    }
    func days(_ raw: [String]?, _ prop: String) throws -> Set<Date> {
        guard let raw else {
            throw ViewRegistryError.unknownView("component.ui2.C-128: props.\(prop) is required ([] = none)")
        }
        return Set(try raw.map { try day($0, prop) })
    }
    guard let lessonCount = c.lessonCount else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: props.lessonCount is required")
    }
    guard let todayRaw = c.today?.stringValue else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: props.today is required (yyyy-MM-dd)")
    }
    guard let enabledDays = c.enabledDays else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: props.enabledDays is required (0 = Sun … 6 = Sat)")
    }
    guard let promptRaw = c.prompt else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: props.prompt is required (none|override(d)|overlap(d))")
    }
    // §3 writes the prompt as `none`, `override(yyyy-MM-dd)` or `overlap(yyyy-MM-dd)`.
    let prompt: UI2Preview.DateRangePicker.Prompt
    if promptRaw == "none" {
        prompt = .none
    } else if promptRaw.hasPrefix("override("), promptRaw.hasSuffix(")") {
        prompt = .override(try day(String(promptRaw.dropFirst(9).dropLast()), "prompt"))
    } else if promptRaw.hasPrefix("overlap("), promptRaw.hasSuffix(")") {
        prompt = .overlap(try day(String(promptRaw.dropFirst(8).dropLast()), "prompt"))
    } else {
        throw ViewRegistryError.unknownView("component.ui2.C-128: props.prompt \"\(promptRaw)\" must be none|override(d)|overlap(d)")
    }
    return declareCase(
        UI2Preview.DateRangePicker(
            lessonCount: lessonCount,
            today: try day(todayRaw, "today"),
            startDate: try c.startDate.map { try day($0, "startDate") },
            enabledDays: Set(enabledDays),
            overriddenDates: try days(c.overriddenDates, "overriddenDates"),
            existingLessonDates: try days(c.existingLessonDates, "existingLessonDates"),
            currentScheduleDates: try days(c.currentScheduleDates, "currentScheduleDates"),
            prompt: prompt
        ),
        // §1: the frozen raster is 440×713 (the full device width, no side margin); a scroll body
        // has no intrinsic height, so the frame pins both.
        PreviewFrame(width: 440, height: 713, margin: 0)
    )
}

/// `component.ui2.C-117` — C-117 CalendarEventBlock. See the case in `buildCaptureViewPart9`.
@MainActor @inline(never)
private func buildUI2C117(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: missing state.component")
    }
    // C-117 §4 (R-07): `title`, `detailKind`, `eventType`, `recurring` and `timeRangeText` are
    // required — a nil is a fixture bug, not a value to guess. `detail` defaults to nil (§4) and
    // `onTap` is the view's no-op default; the pressed dim is ephemeral (R-02), so it renders at rest.
    guard let ui2C117Title = c.title else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: props.title is required")
    }
    guard let ui2C117KindRaw = c.detailKind,
          let ui2C117Kind = UI2Preview.CalendarEventBlock.DetailKind(rawValue: ui2C117KindRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: props.detailKind is required (location|online|group)")
    }
    guard let ui2C117TypeRaw = c.eventType,
          let ui2C117Type = UI2Preview.EventIndicator.EventType(rawValue: ui2C117TypeRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: props.eventType is required (lesson|meeting|online|deadline|social|other)")
    }
    guard let ui2C117Recurring = c.recurring else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: props.recurring is required")
    }
    guard let ui2C117TimeRange = c.timeRangeText else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: props.timeRangeText is required")
    }
    // §2: the block "fills the frame its parent gives (width and height)" — C-120's job. The §3
    // "Preview frame" column (372×20, 372×48, 184×46 …) rides in the harness keys
    // `__frameWidth` / `__frameHeight` (the C-091 precedent), not as §4 props.
    guard let ui2C117Width = c.__frameWidth, let ui2C117Height = c.__frameHeight else {
        throw ViewRegistryError.unknownView("component.ui2.C-117: __frameWidth / __frameHeight (the §3 preview frame) are required")
    }
    return declareCase(
        UI2Preview.CalendarEventBlock(
            title: ui2C117Title,
            detail: c.detail,
            detailKind: ui2C117Kind,
            eventType: ui2C117Type,
            recurring: ui2C117Recurring,
            timeRangeText: ui2C117TimeRange
        ),
        PreviewFrame(width: CGFloat(ui2C117Width), height: CGFloat(ui2C117Height), alignment: .leading)
    )
}

/// `component.ui2.C-115` — C-115 MonthGrid. See the case in `buildCaptureViewPart9`.
@MainActor @inline(never)
private func buildUI2C115(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-115: missing state.component")
    }
    // C-115 §4 (R-07): `month`, `today` and `days` are required — a nil is a fixture bug, not a
    // value to guess. `onSelectDate` is the view's no-op default.
    guard let ui2C115MonthRaw = c.month,
          let ui2C115Month = ui2C113DateFormatter.date(from: String(ui2C115MonthRaw.prefix(10))) else {
        throw ViewRegistryError.unknownView("component.ui2.C-115: props.month is required (yyyy-MM-dd)")
    }
    guard let ui2C115TodayRaw = c.today?.stringValue,
          let ui2C115Today = ui2C115DateTimeFormatter.date(from: ui2C115TodayRaw)
            ?? ui2C113DateFormatter.date(from: String(ui2C115TodayRaw.prefix(10))) else {
        throw ViewRegistryError.unknownView("component.ui2.C-115: props.today is required (yyyy-MM-ddTHH:mm:ss)")
    }
    // An empty `days` array decodes as CaptureDays' first array reading; `[]` = no indicators.
    guard let ui2C115DaysRaw = c.days else {
        throw ViewRegistryError.unknownView("component.ui2.C-115: props.days is required ([] = no indicators)")
    }
    let ui2C115Days = try (ui2C115DaysRaw.monthDays ?? []).map { entry -> UI2Preview.MonthGrid.DayEvents in
        let types = try entry.eventTypes.map { raw -> UI2Preview.EventIndicator.EventType in
            guard let type = UI2Preview.EventIndicator.EventType(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-115: props.days eventTypes \"\(raw)\" must be lesson|meeting|online|deadline|social|other")
            }
            return type
        }
        return UI2Preview.MonthGrid.DayEvents(day: entry.day, eventTypes: types)
    }
    return declareCase(
        UI2Preview.MonthGrid(month: ui2C115Month, today: ui2C115Today, days: ui2C115Days),
        // §2: "the full screen width, no side margin" — the C-114 precedent.
        PreviewFrame(width: 440, margin: 0)
    )
}

/// C-115 `today` is the screen's injected `now` — a local date-time, read in the device's time
/// zone like C-113's dates.
private let ui2C115DateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f
}()

/// C-113 parses its `date` in the device's time zone — the view reads day-of-month and weekday
/// with a Gregorian calendar in the same zone, so a UTC midnight never shifts the day.
private let ui2C113DateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// `screen.2.0.invite-qr` — the Invite QR screen. See the case in `buildCaptureViewPart9`.
@MainActor @inline(never)
private func buildScreenInviteQr(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.invite-qr: missing state.component")
    }
    // A missing field takes this build's `Populated` sample, single-sourced on the screen's
    // State — except `qrCode`, whose absence IS the blank plate (§3 Loading / failed).
    let sample = UI2Preview.InviteQrScreen.State.populated
    // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
    return AnyView(UI2Preview.InviteQrScreen(
        state: .init(
            code: c.code ?? sample.code,
            hintURL: c.hintURL ?? sample.hintURL,
            qrCode: c.qrCode,
            copiedTarget: c.copiedTarget ?? sample.copiedTarget
        )
    ))
}

/// `component.ui2.C-111` — C-111 QRCodeImage. See the case in `buildCaptureViewPart9`.
@MainActor @inline(never)
private func buildUI2C111(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-111: missing state.component")
    }
    // C-111 §4 `image: Image?` — the fixture names the bitmap as the invite endpoints send it
    // (a `data:image/png;base64,…` URL) or by any readable URL, and this case decodes it,
    // playing the caller (R-04 / R-19; the C-087 precedent). Absent is `nil`, the `empty`
    // state. A value that is present but unreadable is a fixture bug.
    var ui2C111Image: Image?
    if let raw = c.image {
        let data: Data?
        if raw.hasPrefix("data:"), let comma = raw.firstIndex(of: ",") {
            data = Data(base64Encoded: String(raw[raw.index(after: comma)...]))
        } else if let url = URL(string: raw) {
            data = try? Data(contentsOf: url)
        } else {
            data = nil
        }
        guard let data, let uiImage = UIImage(data: data) else {
            throw ViewRegistryError.unknownView("component.ui2.C-111: props.image is not a readable image")
        }
        ui2C111Image = Image(uiImage: uiImage)
    }
    return declareCase(
        UI2Preview.QRCodeImage(image: ui2C111Image),
        // C-111 §2: "At the designed size the caller gives it 280pt (invite-qr §2)" — the
        // master width; the view keeps itself square (R-16).
        PreviewFrame(width: 280)
    )
}

/// `screen.2.0.study-programs` — the study-programs screen preview. See the case in
/// `buildCaptureViewPart9`.
@MainActor @inline(never)
private func buildScreenStudyPrograms(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.study-programs: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.StudyProgramsScreen.State.populated
    let programCoverURLs = c.programCoverURLs ?? sample.programCoverURLs
    // C-059 covers: the fixture names each image by URL and the harness resolves the bytes into
    // the preview module's cache (the home-dashboard seam) — the view performs no I/O.
    for raw in programCoverURLs {
        if let url = URL(string: raw), url.scheme != nil,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.StudyProgramsScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
            leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
            loading: c.loading ?? sample.loading,
            failed: c.failed ?? sample.failed,
            programTitles: c.programTitles ?? sample.programTitles,
            programDescriptions: c.programDescriptions ?? sample.programDescriptions,
            programEnrollmentCounts: c.programEnrollmentCounts ?? sample.programEnrollmentCounts,
            programCoverURLs: programCoverURLs
        )
    ))
}

/// `screen.2.0.activities-editor` — the Activity Editor screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenActivitiesEditor(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.activities-editor: missing state.component")
    }
    // A missing field takes this build's `idleEmpty` sample (the frozen frame `blank-canvas`),
    // single-sourced on the screen's State.
    let sample = UI2Preview.ActivitiesEditorScreen.State.idleEmpty
    let pageImageURL = c.pageImageURL ?? sample.pageImageURL
    // Seed the page image synchronously so the snapshot's single layout pass can render it — the
    // C-091 case's mechanism. An unreachable URL leaves C-091 on its §2 placeholder base.
    if let url = URL(string: pageImageURL), url.scheme?.hasPrefix("http") == true,
       let data = try? Data(contentsOf: url), let picture = UIImage(data: data) {
        UI2Preview.Ui2ImageCache.shared.seed(picture, for: url)
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.ActivitiesEditorScreen(
        state: .init(
            editorMode: c.editorMode ?? sample.editorMode,
            openTool: c.openTool ?? sample.openTool,
            slideIDs: c.slideIDs ?? sample.slideIDs,
            slideLabels: c.slideLabels ?? sample.slideLabels,
            activeID: c.activeID ?? sample.activeID,
            objectTexts: c.objectTexts ?? sample.objectTexts,
            objectFonts: c.objectFonts ?? sample.objectFonts,
            objectColors: c.objectColors ?? sample.objectColors,
            objectSizes: c.objectSizes ?? sample.objectSizes,
            objectXs: c.objectXs ?? sample.objectXs,
            objectYs: c.objectYs ?? sample.objectYs,
            objectScales: c.objectScales ?? sample.objectScales,
            objectRotations: c.objectRotations ?? sample.objectRotations,
            draftText: c.draftText ?? sample.draftText,
            draftFont: c.draftFont ?? sample.draftFont,
            draftColor: c.draftColor ?? sample.draftColor,
            draftSize: c.draftSize ?? sample.draftSize,
            draftAlignment: c.draftAlignment ?? sample.draftAlignment,
            pageImageURL: pageImageURL,
            pageWashHex: c.pageWashHex ?? sample.pageWashHex,
            pageWashOpacity: c.pageWashOpacity ?? sample.pageWashOpacity,
            verseTexts: c.verseTexts ?? sample.verseTexts,
            firstVerse: c.firstVerse ?? sample.firstVerse,
            highlightIDs: c.highlightIDs ?? sample.highlightIDs,
            highlightVerses: c.highlightVerses ?? sample.highlightVerses,
            highlightStarts: c.highlightStarts ?? sample.highlightStarts,
            highlightEnds: c.highlightEnds ?? sample.highlightEnds,
            selectedHighlightID: c.selectedHighlightID ?? sample.selectedHighlightID,
            centerGuide: c.centerGuide ?? sample.centerGuide,
            deleteTargetShown: c.deleteTargetShown ?? sample.deleteTargetShown,
            saving: c.saving ?? sample.saving,
            saveFailed: c.saveFailed ?? sample.saveFailed
        )
    ))
}

/// `screen.2.0.search-home` — the search-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenSearchHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.search-home: missing state.component")
    }
    // A missing field takes this build's `recents-populated` sample (the preview linked to the
    // frozen frame `search-home`), single-sourced on the screen's State.
    let sample = UI2Preview.SearchHomeScreen.State.recentsPopulated
    // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
    return AnyView(UI2Preview.SearchHomeScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            activeChip: c.activeChip ?? sample.activeChip,
            recentKinds: c.recentKinds ?? sample.recentKinds,
            recentTitles: c.recentTitles ?? sample.recentTitles,
            recentDescriptions: c.recentDescriptions ?? sample.recentDescriptions,
            resultKinds: c.resultKinds ?? sample.resultKinds,
            resultTitles: c.resultTitles ?? sample.resultTitles,
            resultDescriptions: c.resultDescriptions ?? sample.resultDescriptions
        )
    ))
}

/// `screen.2.0.enrollments-home` — the enrollments-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenEnrollmentsHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollments-home: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentsHomeScreen.State.populated
    let groupPhotoURLs = c.groupPhotoURLs ?? sample.groupPhotoURLs
    let programCoverURLs = c.programCoverURLs ?? sample.programCoverURLs
    // C-038 photos inside C-058 and C-059 covers: the fixture names each image by URL and the
    // harness resolves the bytes into the preview module's cache (the home-dashboard seam) —
    // the view performs no I/O.
    for raw in groupPhotoURLs + programCoverURLs {
        if let url = URL(string: raw), url.scheme != nil,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentsHomeScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
            groupFilterLabel: c.groupFilterLabel ?? sample.groupFilterLabel,
            leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
            statusFilterLabel: c.statusFilterLabel ?? sample.statusFilterLabel,
            loading: c.loading ?? sample.loading,
            failed: c.failed ?? sample.failed,
            groupNames: c.groupNames ?? sample.groupNames,
            groupLeaderNames: c.groupLeaderNames ?? sample.groupLeaderNames,
            groupPhotoURLs: groupPhotoURLs,
            programGroupIndexes: c.programGroupIndexes ?? sample.programGroupIndexes,
            programTitles: c.programTitles ?? sample.programTitles,
            programProgress: c.programProgress ?? sample.programProgress,
            programCompleteCounts: c.programCompleteCounts ?? sample.programCompleteCounts,
            programHours: c.programHours ?? sample.programHours,
            programEnrolledDates: c.programEnrolledDates ?? sample.programEnrolledDates,
            programCoverURLs: programCoverURLs
        )
    ))
}

/// `screen.2.0.groups-detail` — the groups-detail screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenGroupsDetail(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.groups-detail: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.GroupsDetailScreen.State.populated
    let coverURL = c.coverURL ?? sample.coverURL
    let lessonSlideImages = c.lessonSlideImages ?? sample.lessonSlideImages
    let memberPhotoURLs = c.memberPhotoURLs ?? sample.memberPhotoURLs
    let programCoverURLs = c.programCoverURLs ?? sample.programCoverURLs
    // C-087 cover, C-079 screenshots inside C-063, C-038 photos inside C-037 and C-059 covers:
    // the fixture names each image by URL (file:// or http[s]) and the harness resolves the
    // bytes into the preview module's cache (the home-dashboard seam) — the view performs no I/O.
    for raw in [coverURL] + lessonSlideImages.flatMap({ $0 }) + memberPhotoURLs + programCoverURLs {
        if let url = URL(string: raw), url.scheme != nil,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.GroupsDetailScreen(
        state: .init(
            groupName: c.groupName ?? sample.groupName,
            coverURL: coverURL,
            leaderName: c.leaderName ?? sample.leaderName,
            createdLabel: c.createdLabel ?? sample.createdLabel,
            groupDescription: c.groupDescription ?? sample.groupDescription,
            visibility: c.visibility ?? sample.visibility,
            ageRange: c.ageRange ?? sample.ageRange,
            maximumMembers: c.maximumMembers ?? sample.maximumMembers,
            memberDirectoryAccess: c.memberDirectoryAccess ?? sample.memberDirectoryAccess,
            lessonTitles: c.lessonTitles ?? sample.lessonTitles,
            lessonProgramNames: c.lessonProgramNames ?? sample.lessonProgramNames,
            lessonMetaLabels: c.lessonMetaLabels ?? sample.lessonMetaLabels,
            lessonSlideImages: lessonSlideImages,
            lessonSlideLabels: c.lessonSlideLabels ?? sample.lessonSlideLabels,
            dayMonths: c.dayMonths ?? sample.dayMonths,
            dayWeekdays: c.dayWeekdays ?? sample.dayWeekdays,
            dayNumbers: c.dayNumbers ?? sample.dayNumbers,
            dayDateStates: c.dayDateStates ?? sample.dayDateStates,
            daySeries: c.daySeries ?? sample.daySeries,
            dayLine1s: c.dayLine1s ?? sample.dayLine1s,
            dayLine2s: c.dayLine2s ?? sample.dayLine2s,
            dayDetailsStates: c.dayDetailsStates ?? sample.dayDetailsStates,
            chartDates: c.chartDates ?? sample.chartDates,
            chartScheduled: c.chartScheduled ?? sample.chartScheduled,
            chartCompleted: c.chartCompleted ?? sample.chartCompleted,
            chartWindowStart: c.chartWindowStart ?? sample.chartWindowStart,
            chartWindowEnd: c.chartWindowEnd ?? sample.chartWindowEnd,
            chartToday: c.chartToday ?? sample.chartToday,
            memberNames: c.memberNames ?? sample.memberNames,
            memberPhotoURLs: memberPhotoURLs,
            memberJoinedLabels: c.memberJoinedLabels ?? sample.memberJoinedLabels,
            requestNames: c.requestNames ?? sample.requestNames,
            requestDates: c.requestDates ?? sample.requestDates,
            programTitles: c.programTitles ?? sample.programTitles,
            programDescriptions: c.programDescriptions ?? sample.programDescriptions,
            programEnrolledDates: c.programEnrolledDates ?? sample.programEnrolledDates,
            programCoverURLs: programCoverURLs,
            eventDates: c.eventDates ?? sample.eventDates,
            eventTexts: c.eventTexts ?? sample.eventTexts,
            eventHighlights: c.eventHighlights ?? sample.eventHighlights,
            eventTones: c.eventTones ?? sample.eventTones
        )
    ))
}

/// `screen.2.0.invites-home` — the invites-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenInvitesHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.invites-home: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.InvitesHomeScreen.State.populated
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.InvitesHomeScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
            groupFilterLabel: c.groupFilterLabel ?? sample.groupFilterLabel,
            leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
            statusFilterLabel: c.statusFilterLabel ?? sample.statusFilterLabel,
            loading: c.loading ?? sample.loading,
            inviteRecipients: c.inviteRecipients ?? sample.inviteRecipients,
            inviteStatuses: c.inviteStatuses ?? sample.inviteStatuses,
            inviteGroupNames: c.inviteGroupNames ?? sample.inviteGroupNames,
            inviteDates: c.inviteDates ?? sample.inviteDates
        )
    ))
}

/// `screen.2.0.enrollment-home` — the enrollment-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenEnrollmentHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-home: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentHomeScreen.State.populated
    let coverURL = c.coverURL ?? sample.coverURL
    let lessonSlideImages = c.lessonSlideImages ?? sample.lessonSlideImages
    // C-087 cover and C-079 screenshots inside C-063: the fixture names each image by URL
    // (file:// or http[s]) and the harness resolves the bytes into the preview module's cache
    // (the home-dashboard seam) — the view itself performs no I/O.
    for raw in [coverURL] + lessonSlideImages.flatMap({ $0 }) {
        if let url = URL(string: raw), url.scheme != nil,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentHomeScreen(
        state: .init(
            coverURL: coverURL,
            programName: c.programName ?? sample.programName,
            programDescription: c.programDescription ?? sample.programDescription,
            memberCount: c.memberCount ?? sample.memberCount,
            authorName: c.authorName ?? sample.authorName,
            enrolledLabel: c.enrolledLabel ?? sample.enrolledLabel,
            leaderName: c.leaderName ?? sample.leaderName,
            startMonth: c.startMonth ?? sample.startMonth,
            startWeekday: c.startWeekday ?? sample.startWeekday,
            startDay: c.startDay ?? sample.startDay,
            endMonth: c.endMonth ?? sample.endMonth,
            endWeekday: c.endWeekday ?? sample.endWeekday,
            endDay: c.endDay ?? sample.endDay,
            spanMonths: c.spanMonths ?? sample.spanMonths,
            spanDays: c.spanDays ?? sample.spanDays,
            dayMonths: c.dayMonths ?? sample.dayMonths,
            dayWeekdays: c.dayWeekdays ?? sample.dayWeekdays,
            dayNumbers: c.dayNumbers ?? sample.dayNumbers,
            dayDateStates: c.dayDateStates ?? sample.dayDateStates,
            dayPercents: c.dayPercents ?? sample.dayPercents,
            dayLine1s: c.dayLine1s ?? sample.dayLine1s,
            dayLine2s: c.dayLine2s ?? sample.dayLine2s,
            dayDetailsStates: c.dayDetailsStates ?? sample.dayDetailsStates,
            lessonNumbers: c.lessonNumbers ?? sample.lessonNumbers,
            lessonTitles: c.lessonTitles ?? sample.lessonTitles,
            lessonMetaLabels: c.lessonMetaLabels ?? sample.lessonMetaLabels,
            lessonProgress: c.lessonProgress ?? sample.lessonProgress,
            lessonSlideImages: lessonSlideImages,
            lessonSlideLabels: c.lessonSlideLabels ?? sample.lessonSlideLabels
        )
    ))
}

/// `screen.2.0.invite-home` — the invite-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenInviteHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.invite-home: missing state.component")
    }
    // A missing field takes this build's `unlinked` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.InviteHomeScreen.State.unlinked
    let avatarURL = c.avatarURL ?? sample.avatarURL
    let groupPhotoURLs = c.groupPhotoURLs ?? sample.groupPhotoURLs
    // C-038 photos (the member block, and inside C-037): the fixture names each image by URL and
    // the harness resolves the bytes into the preview module's cache (the home-dashboard seam) —
    // the view itself performs no network.
    for raw in [avatarURL] + groupPhotoURLs {
        if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.InviteHomeScreen(
        state: .init(
            phone: c.phone ?? sample.phone,
            memberLinked: c.memberLinked ?? sample.memberLinked,
            sentDate: c.sentDate ?? sample.sentDate,
            invitedBy: c.invitedBy ?? sample.invitedBy,
            memberName: c.memberName ?? sample.memberName,
            avatarURL: avatarURL,
            initials: c.initials ?? sample.initials,
            age: c.age ?? sample.age,
            role: c.role ?? sample.role,
            birthday: c.birthday ?? sample.birthday,
            joined: c.joined ?? sample.joined,
            groupTitles: c.groupTitles ?? sample.groupTitles,
            groupPhotoURLs: groupPhotoURLs,
            groupStatuses: c.groupStatuses ?? sample.groupStatuses,
            groupStatusDates: c.groupStatusDates ?? sample.groupStatusDates,
            eventDates: c.eventDates ?? sample.eventDates,
            eventTexts: c.eventTexts ?? sample.eventTexts,
            eventHighlights: c.eventHighlights ?? sample.eventHighlights,
            eventTones: c.eventTones ?? sample.eventTones
        )
    ))
}

/// `screen.2.0.study-program-home` — the study-program-home screen preview. See the case in
/// `buildCaptureView`.
@MainActor @inline(never)
private func buildScreenStudyProgramHome(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.study-program-home: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.StudyProgramHomeScreen.State.populated
    let coverURL = c.coverURL ?? sample.coverURL
    let enrollmentPhotoURLs = c.enrollmentPhotoURLs ?? sample.enrollmentPhotoURLs
    let lessonSlideImages = c.lessonSlideImages ?? sample.lessonSlideImages
    // C-087 cover, C-038 photos inside C-037 and C-079 screenshots inside C-063: the fixture
    // names each image by URL (file:// or http[s]) and the harness resolves the bytes into the
    // preview module's cache (the home-dashboard seam) — the view itself performs no I/O.
    for raw in [coverURL] + enrollmentPhotoURLs + lessonSlideImages.flatMap({ $0 }) {
        if let url = URL(string: raw), url.scheme != nil,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.StudyProgramHomeScreen(
        state: .init(
            coverURL: coverURL,
            createdLabel: c.createdLabel ?? sample.createdLabel,
            authorName: c.authorName ?? sample.authorName,
            leaderName: c.leaderName ?? sample.leaderName,
            lessonCount: c.lessonCount ?? sample.lessonCount,
            programName: c.programName ?? sample.programName,
            programDescription: c.programDescription ?? sample.programDescription,
            visibility: c.visibility ?? sample.visibility,
            ageRange: c.ageRange ?? sample.ageRange,
            maximumMembers: c.maximumMembers ?? sample.maximumMembers,
            memberDirectoryAccess: c.memberDirectoryAccess ?? sample.memberDirectoryAccess,
            enrollmentNames: c.enrollmentNames ?? sample.enrollmentNames,
            enrollmentPhotoURLs: enrollmentPhotoURLs,
            enrollmentLeaders: c.enrollmentLeaders ?? sample.enrollmentLeaders,
            enrollmentMemberCounts: c.enrollmentMemberCounts ?? sample.enrollmentMemberCounts,
            dayCount: c.dayCount ?? sample.dayCount,
            activeDay: c.activeDay ?? sample.activeDay,
            lessonNumbers: c.lessonNumbers ?? sample.lessonNumbers,
            lessonTitles: c.lessonTitles ?? sample.lessonTitles,
            lessonDurations: c.lessonDurations ?? sample.lessonDurations,
            lessonSlideImages: lessonSlideImages,
            lessonSlideLabels: c.lessonSlideLabels ?? sample.lessonSlideLabels
        )
    ))
}

/// `component.ui2.C-087` — C-087 CoverImage. See the case in `buildCaptureView`.
@MainActor @inline(never)
private func buildUI2C087(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-087: missing state.component")
    }
    // C-087 §4 `image: Image?` — the fixture names the cover by URL and this case resolves
    // it, playing the caller (R-04 / R-19; the C-079 precedent). Absent is `nil`, the
    // `No cover` state. A URL that is present but unreadable is a fixture bug.
    var ui2C087Image: Image?
    if let raw = c.image {
        guard let url = URL(string: raw), let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else {
            throw ViewRegistryError.unknownView("component.ui2.C-087: props.image \"\(raw)\" is not a readable image URL")
        }
        ui2C087Image = Image(uiImage: uiImage)
    }
    return declareCase(
        UI2Preview.CoverImage(image: ui2C087Image),
        // C-087 §2: "408 on the 440 frame" — the master width. Margin and ground live
        // here (R-16).
        PreviewFrame(width: 408)
    )
}

@MainActor @inline(never)
private func buildScreenActivityNew(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.activity-new: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.ActivityNewScreen.State.populated
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.ActivityNewScreen(
        state: .init(
            slideIDs: c.slideIDs ?? sample.slideIDs,
            slideLabels: c.slideLabels ?? sample.slideLabels,
            activeID: c.activeID ?? sample.activeID,
            pendingType: c.pendingType ?? sample.pendingType,
            createFailed: c.createFailed ?? sample.createFailed
        )
    ))
}

/// C-026 fixture dates: `yyyy-MM-dd` read as UTC, matching how DualSeriesBarChart formats its
/// tick labels — so a fixture date renders as the day it names in any simulator zone.
private let ui2ChartDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// `component.ui2.C-083` — C-083 TabBarButton. See the case in `buildCaptureView`.
@MainActor @inline(never)
private func buildUI2C083(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-083: missing state.component")
    }
    // C-083 §4: `glyph`, `accessibilityLabel` and `active` are required (R-07), so a nil is
    // a fixture bug; `glyph` must be a library glyph. `onTap` is a no-op in the view.
    guard let ui2C083GlyphRaw = c.glyph else {
        throw ViewRegistryError.unknownView("component.ui2.C-083: missing props.glyph")
    }
    guard let ui2C083Glyph = UI2Preview.GlyphName(rawValue: ui2C083GlyphRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-083: props.glyph \"\(ui2C083GlyphRaw)\" is not a library glyph")
    }
    guard let ui2C083Label = c.accessibilityLabel else {
        throw ViewRegistryError.unknownView("component.ui2.C-083: missing props.accessibilityLabel")
    }
    guard let ui2C083Active = c.active else {
        throw ViewRegistryError.unknownView("component.ui2.C-083: missing props.active")
    }
    return declareCase(
        UI2Preview.TabBarButton(
            glyph: ui2C083Glyph,
            accessibilityLabel: ui2C083Label,
            active: ui2C083Active
        ),
        // C-083 §2: minimum width 54 (16 + 22 + 16) — the designed symbol width. Margin
        // and ground live here (R-16).
        PreviewFrame(width: 54)
    )
}

@MainActor @inline(never)
private func buildUI2C085(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-085: missing state.component")
    }
    // C-085 §4: `kind`, `title` and `trailing` are required (R-07), so a nil is a fixture bug;
    // `description` defaults to nil. `onTap` / `onRemove` are no-ops in a still capture.
    guard let ui2C085Kind = c.kind.flatMap(UI2Preview.SearchResultRow.Kind.init(rawValue:)) else {
        throw ViewRegistryError.unknownView(
            "component.ui2.C-085: props.kind must be member|media|program|group|lesson|event|post")
    }
    guard let ui2C085Title = c.title else {
        throw ViewRegistryError.unknownView("component.ui2.C-085: props.title is required")
    }
    guard let ui2C085Trailing = c.trailing.flatMap(UI2Preview.SearchResultRow.Trailing.init(rawValue:)) else {
        throw ViewRegistryError.unknownView("component.ui2.C-085: props.trailing must be remove|none")
    }
    return declareCase(
        UI2Preview.SearchResultRow(
            kind: ui2C085Kind,
            title: ui2C085Title,
            description: c.description,
            trailing: ui2C085Trailing
        ),
        // C-085 §1: the instance is 408 wide on search-home — the master width. Margin and
        // ground live here (R-16).
        PreviewFrame(width: 408)
    )
}

@MainActor @inline(never)
private func buildUI2C086(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-086: missing state.component")
    }
    // C-086 §4: `pendingType` is required but optional-typed — a missing key is `nil`
    // (interactive, §3 default); a present one must be an ActivityType case. `onSelect` is a
    // no-op in a still capture. Out of line for the same stack-frame reason as C-083.
    let ui2C086Pending: UI2Preview.ActivityTypeGrid.ActivityType?
    if let raw = c.pendingType {
        guard let type = UI2Preview.ActivityTypeGrid.ActivityType(rawValue: raw) else {
            throw ViewRegistryError.unknownView(
                "component.ui2.C-086: props.pendingType must be bibleVerse|text|video|youtube|write|poll")
        }
        ui2C086Pending = type
    } else {
        ui2C086Pending = nil
    }
    return declareCase(
        UI2Preview.ActivityTypeGrid(pendingType: ui2C086Pending),
        // C-086 §2: "Designed at 408 wide" — the master width; the height (556) follows from
        // it. Margin and ground live here (R-16).
        PreviewFrame(width: 408)
    )
}

/// `component.ui2.C-088` — C-088 SectionDivider. See the case in `buildCaptureView`.
@MainActor @inline(never)
private func buildUI2C088(_ fixture: CaptureFixture) throws -> AnyView {
    // C-088 §4: no props, so `state.component` carries nothing to decode and is not required.
    // Out of line for the same stack-frame reason as C-083.
    declareCase(
        UI2Preview.SectionDivider(),
        // C-088 §2: "408 pt on study-program-home" — the master width. Margin and ground live
        // here (R-16).
        PreviewFrame(width: 408)
    )
}

/// `component.ui2.C-089` — C-089 InviteStatusRow. Out of line for the same stack-frame reason
/// as C-083.
@MainActor @inline(never)
private func buildUI2C089(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-089: missing state.component")
    }
    // C-089 §4: `recipient`, `status`, `groupName` and `date` are required with no default
    // (R-07) — a nil is a fixture bug, not a value to guess. `onTap` is a no-op in the view.
    guard let ui2C089Recipient = c.recipient else {
        throw ViewRegistryError.unknownView("component.ui2.C-089: props.recipient is required")
    }
    guard let ui2C089StatusRaw = c.status,
          let ui2C089Status = UI2Preview.InviteStatusRow.Status(rawValue: ui2C089StatusRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-089: props.status must be sent|requested|accepted|rejected|expired")
    }
    guard let ui2C089GroupName = c.groupName else {
        throw ViewRegistryError.unknownView("component.ui2.C-089: props.groupName is required")
    }
    guard let ui2C089Date = c.date?.string else {
        throw ViewRegistryError.unknownView("component.ui2.C-089: props.date is required")
    }
    return declareCase(
        UI2Preview.InviteStatusRow(
            recipient: ui2C089Recipient,
            status: ui2C089Status,
            groupName: ui2C089GroupName,
            date: ui2C089Date
        ),
        // C-089 §2: "fills the width it is given (408 in the frame)" — the master width.
        // Margin and ground live here (R-16).
        PreviewFrame(width: 408)
    )
}

/// `screen.2.0.home-kpi-picker` — the home-kpi-picker screen preview. Out of line for the same
/// stack-frame reason as C-083: it composes C-090 KPIPickerRow, whose body type is deep.
@MainActor @inline(never)
private func buildScreenHomeKpiPicker(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.home-kpi-picker: missing state.component")
    }
    // A missing field takes this build's `populated` sample (the preview linked to the frozen
    // frame `design-14`), single-sourced on the screen's State.
    let sample = UI2Preview.HomeKpiPickerScreen.State.populated
    // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
    return AnyView(UI2Preview.HomeKpiPickerScreen(
        state: .init(
            kpiNames: c.kpiNames ?? sample.kpiNames,
            kpiDescriptions: c.kpiDescriptions ?? sample.kpiDescriptions,
            kpiSeries: c.kpiSeries ?? sample.kpiSeries,
            kpiAverageLabels: c.kpiAverageLabels ?? sample.kpiAverageLabels,
            kpiValues: c.kpiValues ?? sample.kpiValues,
            kpiTrendDirections: c.kpiTrendDirections ?? sample.kpiTrendDirections,
            kpiTrendPolarities: c.kpiTrendPolarities ?? sample.kpiTrendPolarities,
            kpiTrendLabels: c.kpiTrendLabels ?? sample.kpiTrendLabels
        )
    ))
}

/// `screen.2.0.login` — the Login screen preview (D5: Screens/Auth/LoginScreen.swift). Out of
/// line with the other screen cases so its type metadata resolves without the inline builder's
/// Debug stack frame beneath it.
@MainActor @inline(never)
private func buildScreenLogin(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.login: missing state.component")
    }
    // A missing field takes this build's `idle` sample (the preview linked to the frozen frame
    // `default`), single-sourced on the screen's State.
    let sample = UI2Preview.LoginScreen.State.idle
    // The canvas is the harness's (CaptureRunner's `screen.*` branch) — the bare screen here.
    return AnyView(UI2Preview.LoginScreen(
        state: .init(
            authenticating: c.authenticating ?? sample.authenticating,
            errorMessage: c.errorMessage ?? sample.errorMessage
        )
    ))
}

/// `component.ui2.C-090` — the KPIPickerRow preview. Out of line for the same stack-frame
/// reason as C-083: it composes C-023 RailCard, whose body type is deep.
@MainActor @inline(never)
private func buildUI2C090(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: missing state.component")
    }
    // C-090 §4: every prop is required (R-07) except `averageLabel` (nil = average line only)
    // and `onAdd` (no-op default in the view) — a nil anywhere else is a fixture bug, not a
    // value to guess. All nine names already decode on `CaptureComponent` under the
    // contract's own names and types (C-023 / C-024 added them), so no field was added.
    guard let ui2C090Name = c.name else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.name is required")
    }
    guard let ui2C090Description = c.description else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.description is required")
    }
    guard let ui2C090Series = c.series else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.series is required")
    }
    guard let ui2C090Value = c.value else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.value is required")
    }
    // `trendDirection` / `trendPolarity` take C-077's value sets, cited by §4: an unknown
    // value throws rather than rendering a plausible arrow.
    guard let ui2C090DirectionRaw = c.trendDirection,
          let ui2C090Direction = UI2Preview.TrendIndicator.Direction(rawValue: ui2C090DirectionRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.trendDirection must be up|down|neutral")
    }
    guard let ui2C090PolarityRaw = c.trendPolarity,
          let ui2C090Polarity = UI2Preview.TrendIndicator.Polarity(rawValue: ui2C090PolarityRaw) else {
        throw ViewRegistryError.unknownView(
            "component.ui2.C-090: props.trendPolarity must be positive|negative|neutral"
        )
    }
    guard let ui2C090TrendLabel = c.trendLabel else {
        throw ViewRegistryError.unknownView("component.ui2.C-090: props.trendLabel is required")
    }
    return declareCase(
        UI2Preview.KPIPickerRow(
            name: ui2C090Name,
            description: ui2C090Description,
            series: ui2C090Series,
            averageLabel: c.averageLabel,
            value: ui2C090Value,
            trendDirection: ui2C090Direction,
            trendPolarity: ui2C090Polarity,
            trendLabel: ui2C090TrendLabel
        ),
        // C-090 §2: "On home-kpi-picker the row gets the list's inner width (page − 32 = 408
        // on the 440pt reference device)" — the master width. Margin and ground live here
        // (R-16); the row itself is transparent (note 2026-10-06T13:07:44.019Z).
        PreviewFrame(width: 408)
    )
}

/// `component.ui2.C-104` — the AuthProviderButton preview. Out of line as every case since
/// C-083 is (the stack-frame reason): it composes C-076 ActivitySpinner.
@MainActor @inline(never)
private func buildUI2C104(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-104: missing state.component")
    }
    // C-104 §4: `provider` is required (R-07) — a nil is a fixture bug, not a value to guess —
    // and takes the enum's one case; `loading` defaults to false (the design shows the idle
    // tile); `onTap` is the view's no-op default. §3 `pressed` is ephemeral (R-02) and has no
    // prop to set, so `google-pressed` renders the tile at rest, as C-082's does.
    guard let ui2C104ProviderRaw = c.provider else {
        throw ViewRegistryError.unknownView("component.ui2.C-104: props.provider is required")
    }
    let ui2C104Provider: UI2Preview.AuthProviderButton.Provider
    switch ui2C104ProviderRaw {
    case "google": ui2C104Provider = .google
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-104: props.provider must be google")
    }
    return declareCase(
        UI2Preview.AuthProviderButton(provider: ui2C104Provider, loading: c.loading ?? false)
            // C-076 inside: the drawn frame is phase 0; with animations off its spin lands
            // back on phase 0, as C-076's own case does.
            .transaction { $0.disablesAnimations = true },
        // C-104 §2: intrinsic 96×96 on both axes — no master width; the call site supplies the
        // page margin and the ground only (R-16), centred as login §2 centres the stack.
        PreviewFrame(intrinsic: true)
    )
}

/// `component.ui2.C-102` — the IconButton preview. Out of line for the same stack-frame reason
/// as C-083.
@MainActor @inline(never)
private func buildUI2C102(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: missing state.component")
    }
    // C-102 §4 (R-07): `glyph`, `tone`, `style`, `selected` and `accessibilityLabel` are
    // required — a nil is a fixture bug, not a value to guess. `onTap` is the view's no-op
    // default. §3 `pressed` is ephemeral (R-02, OQ-C-102-5) and has no prop to set, so it
    // renders at rest, as C-082's does. Every prop reuses an existing field under §4's name.
    guard let ui2C102GlyphRaw = c.glyph else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.glyph is required")
    }
    guard let ui2C102Glyph = UI2Preview.GlyphName(rawValue: ui2C102GlyphRaw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.glyph \"\(ui2C102GlyphRaw)\" is not a library glyph")
    }
    guard let ui2C102Tone = c.tone.flatMap(UI2Preview.IconButton.Tone.init(rawValue:)) else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.tone must be default|destructive")
    }
    guard let ui2C102Style = c.style.flatMap(UI2Preview.IconButton.Style.init(rawValue:)) else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.style must be outlined|plain")
    }
    guard let ui2C102Selected = c.selected?.boolValue else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.selected is required")
    }
    guard let ui2C102Label = c.accessibilityLabel else {
        throw ViewRegistryError.unknownView("component.ui2.C-102: props.accessibilityLabel is required")
    }
    return declareCase(
        UI2Preview.IconButton(
            glyph: ui2C102Glyph,
            tone: ui2C102Tone,
            style: ui2C102Style,
            selected: ui2C102Selected,
            accessibilityLabel: ui2C102Label
        ),
        // No master width: §2 fixes the control at 34×34 and the host positions it, so the
        // call site adds only the page margin and the ground (R-16).
        PreviewFrame(intrinsic: true)
    )
}

/// `component.ui2.C-092` — the CanvasTextObject preview. Out of line for the same stack-frame
/// reason as C-083.
@MainActor @inline(never)
private func buildUI2C092(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-092: missing state.component")
    }
    // C-092 §4 (R-07): `text`, `font`, `size` and `editing` are required — a nil is a fixture bug,
    // not a value to guess. Every other prop takes the contract's default; the callbacks are the
    // view's no-ops.
    guard let ui2C092Text = c.text else {
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.text is required")
    }
    let ui2C092Font: UI2Preview.CanvasTextObject.Font
    switch c.font {
    case "poppins": ui2C092Font = .poppins
    case "sfPro": ui2C092Font = .sfPro
    case "georgia": ui2C092Font = .georgia
    case "typewriter": ui2C092Font = .typewriter
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.font must be poppins|sfPro|georgia|typewriter")
    }
    guard let ui2C092Size = c.size?.doubleValue else {
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.size (points) is required")
    }
    guard let ui2C092Editing = c.editing else {
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.editing is required")
    }
    // `color` arrives as a token row name (the §3 rows cite `color-text-primary`) or a #rrggbb
    // swatch value (C-096's per-screen literals); absent = the contract's `Token.textPrimary`.
    let ui2C092Color: Color
    switch c.color {
    case nil, "color-text-primary": ui2C092Color = UI2Preview.Token.textPrimary
    case let raw?:
        let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else {
            throw ViewRegistryError.unknownView("component.ui2.C-092: props.color \"\(raw)\" must be color-text-primary or #rrggbb")
        }
        ui2C092Color = Color(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }
    let ui2C092Alignment: UI2Preview.CanvasTextObject.Alignment
    switch c.alignment {
    case nil, "center": ui2C092Alignment = .center
    case "left": ui2C092Alignment = .left
    case "right": ui2C092Alignment = .right
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.alignment \"\(other)\" must be center|left|right")
    }
    let ui2C092Label: UI2Preview.CanvasTextObject.Label
    switch c.label {
    case nil, "none": ui2C092Label = .none
    case "solidDark": ui2C092Label = .solidDark
    case "solidLight": ui2C092Label = .solidLight
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.label \"\(other)\" must be none|solidDark|solidLight")
    }
    let ui2C092ListStyle: UI2Preview.CanvasTextObject.ListStyle
    switch c.listStyle {
    case nil, "none": ui2C092ListStyle = .none
    case "bullet": ui2C092ListStyle = .bullet
    case "numbered": ui2C092ListStyle = .numbered
    case "bibleVerse": ui2C092ListStyle = .bibleVerse
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.listStyle \"\(other)\" must be none|bullet|numbered|bibleVerse")
    }
    let ui2C092Animation: UI2Preview.CanvasTextObject.Animation
    switch c.animation {
    case nil, "none": ui2C092Animation = .none
    case "typewriter": ui2C092Animation = .typewriter
    case "pop": ui2C092Animation = .pop
    case "jump": ui2C092Animation = .jump
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.animation \"\(other)\" must be none|typewriter|pop|jump")
    }
    let ui2C092Effect: UI2Preview.CanvasTextObject.Effect
    switch c.effect {
    case nil, "none": ui2C092Effect = .none
    case "sparkle": ui2C092Effect = .sparkle
    case "neon": ui2C092Effect = .neon
    case "shimmer": ui2C092Effect = .shimmer
    case "pixel": ui2C092Effect = .pixel
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-092: props.effect \"\(other)\" must be none|sparkle|neon|shimmer|pixel")
    }
    let ui2C092Reference = c.reference.map { r in
        UI2Preview.CanvasTextObject.Reference(
            start: .init(book: r.start.book, chapter: r.start.chapter, verse: r.start.verse),
            end: r.end.map { .init(book: $0.book, chapter: $0.chapter, verse: $0.verse) }
        )
    }
    var ui2C092Transform = UI2Preview.CanvasTextObject.Transform.identity
    if let t = c.transform {
        if let p = t.position { ui2C092Transform.position = CGPoint(x: p.x, y: p.y) }
        if let scale = t.scale { ui2C092Transform.scale = scale }
        if let rotation = t.rotation { ui2C092Transform.rotation = .degrees(rotation) }
        ui2C092Transform.width = t.width.map { CGFloat($0) }
    }
    // §4 `highlights` ranges index into `text`; the fixture carries them as character offsets.
    let ui2C092Highlights: [UI2Preview.CanvasTextObject.TextRange] = try (c.highlights ?? []).map { h in
        guard h.start >= 0, h.start <= h.end, h.end <= ui2C092Text.count else {
            throw ViewRegistryError.unknownView("component.ui2.C-092: highlight \(h.start)..<\(h.end) is outside props.text")
        }
        let lower = ui2C092Text.index(ui2C092Text.startIndex, offsetBy: h.start)
        let upper = ui2C092Text.index(ui2C092Text.startIndex, offsetBy: h.end)
        return .init(range: lower..<upper, note: nil)
    }
    // A committed object's scale and rotation draw outside its layout box (§2 Transform); the
    // call site gives the turned block room so the capture does not clip it.
    let ui2C092Turned = !ui2C092Editing && ui2C092Transform != .identity
    return declareCase(
        UI2Preview.CanvasTextObject(
            text: ui2C092Text,
            font: ui2C092Font,
            size: CGFloat(ui2C092Size),
            color: ui2C092Color,
            alignment: ui2C092Alignment,
            label: ui2C092Label,
            listStyle: ui2C092ListStyle,
            startNumber: c.startNumber ?? 1,
            reference: ui2C092Reference,
            animation: ui2C092Animation,
            effect: ui2C092Effect,
            transform: ui2C092Transform,
            editing: ui2C092Editing,
            highlights: ui2C092Highlights
        )
        .padding(.vertical, ui2C092Turned ? CGFloat(ui2C092Size) * ui2C092Transform.scale * 1.5 : 0)
        // The looping animations rest at phase 1 (every glyph set) when animations are off.
        .transaction { $0.disablesAnimations = true },
        // C-092 §2 Width & wrapping: with `transform.width` nil the block fills C-091's edit slot,
        // canvas width − 2 × 24pt = 392 on the 440 canvas (FLAGGED LITERAL — the 24pt inset is
        // C-091's). The master width, margin and ground live here (R-16).
        PreviewFrame(width: 392)
    )
}

/// `component.ui2.C-093` — the TextSizeSlider preview. Out of line for the same stack-frame reason
/// as C-083.
@MainActor @inline(never)
private func buildUI2C093(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-093: missing state.component")
    }
    // C-093 §4: `value` is required (R-07 — the frame's 50 % is sample state, §1 deviation 1), so a
    // nil is a fixture bug, not a value to guess. `onChange` is the view's no-op default.
    // The shared `value` field is `String?` (C-022/C-043/C-090's) and may not be retyped, so the
    // fixture carries C-093's CGFloat as a numeric string, parsed here.
    guard let ui2C093Raw = c.value, let ui2C093Value = Double(ui2C093Raw) else {
        throw ViewRegistryError.unknownView("component.ui2.C-093: props.value (0…1) is required")
    }
    return declareCase(
        UI2Preview.TextSizeSlider(value: CGFloat(ui2C093Value)),
        // C-093 §2: the frame is 20 × 263.5pt, intrinsic — the master width is the track's own.
        PreviewFrame(width: 20, height: 263.5)
    )
}

/// `component.ui2.C-084` — the TabBar preview. Out of line for the same stack-frame reason as
/// C-083.
@MainActor @inline(never)
private func buildUI2C084(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-084: missing state.component")
    }
    // C-084 §4: `selected` is required but optional-typed. A missing or null value is `nil`,
    // the none-selected state. Any other value must be a `Tab` case. `onSelect` and `onAdd`
    // are no-ops in the view.
    let ui2C084Selected: UI2Preview.TabBar.Tab?
    switch c.selected?.stringValue {
    case nil: ui2C084Selected = nil
    case "home": ui2C084Selected = .home
    case "calendar": ui2C084Selected = .calendar
    case "search": ui2C084Selected = .search
    case "profile": ui2C084Selected = .profile
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-084: props.selected \"\(other)\" must be home|calendar|search|profile|null")
    }
    return AnyView(
        UI2Preview.TabBar(selected: ui2C084Selected)
        // C-084 §2: 440 on the capture device, the master width. OQ-C-084-003: the bar owns
        // its own pageMargin insets and fill, so there is no extra call-site margin. A 440 bar
        // plus a 16pt margin would overflow the 440pt device.
        .frame(width: 440)
        .frame(maxWidth: .infinity)
        .background(UI2Preview.Token.layoutBackground)
    )
}

@MainActor @inline(never)
private func buildUI2C037(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-037: missing state.component")
    }
    // C-037 §4: `subject`, `title`, `detail` and `trailing` are required (no contract
    // default), so a nil is a fixture bug. `description`/`count`/`imageURL`/`initials`
    // default to nil and `chips` to []; `onTap` (nil = inert) and `onCancel` (no-op) have no
    // render effect in a still capture.
    let ui2C037Subject: UI2Preview.ListResultRow.Subject
    switch c.subject {
    case "member": ui2C037Subject = .member
    case "group": ui2C037Subject = .group
    case "program": ui2C037Subject = .program
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.subject must be member|group|program")
    }
    guard let ui2C037Title = c.title else {
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.title is required")
    }
    let ui2C037Detail: UI2Preview.ListResultRow.Detail
    switch c.detail {
    case "text": ui2C037Detail = .text
    case "chips": ui2C037Detail = .chips
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.detail must be text|chips")
    }
    let ui2C037Trailing: UI2Preview.ListResultRow.Trailing
    switch c.trailing {
    case "chevron": ui2C037Trailing = .chevron
    case "cancel": ui2C037Trailing = .cancel
    case "none": ui2C037Trailing = .none
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.trailing must be chevron|cancel|none")
    }
    // C-037 §4 `selection` defaults to `.none` (the list form); "`trailing` must be `none` when
    // `selection ≠ none`", so any other pairing is a fixture bug.
    let ui2C037Selection: UI2Preview.ListResultRow.Selection
    switch c.selection ?? "none" {
    case "none": ui2C037Selection = .none
    case "unselected": ui2C037Selection = .unselected
    case "selected": ui2C037Selection = .selected
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.selection must be none|unselected|selected")
    }
    if ui2C037Selection != .none, ui2C037Trailing != .none {
        throw ViewRegistryError.unknownView("component.ui2.C-037: props.trailing must be none when selection is not none")
    }
    // Each `chips` entry is a C-043 MetaChip's own §4 props, spelled as C-043 §4 spells them
    // (`state`, `labelPosition`) with C-043's defaults (C-037 §4; OQ-C-037-002).
    var ui2C037Chips: [UI2Preview.ListResultRow.Chip] = []
    for (index, item) in (c.chips ?? []).enumerated() {
        guard let value = item.value else {
            throw ViewRegistryError.unknownView("component.ui2.C-037: chips[\(index)].value is required")
        }
        // C-043 §4 renamed `purple` → `accent` (OQ-C-043-5) and `align: left|right` →
        // `labelPosition: trailing|leading` (OQ-C-043-1); C-037 §4 now spells it `labelPosition`.
        let state: UI2Preview.MetaChip.State
        switch item.state ?? "default" {
        case "default": state = .default
        case "accent", "purple": state = .accent
        case "complete": state = .complete
        case "highlighted": state = .highlighted
        case "muted": state = .muted
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-037: chips[\(index)].state must be default|accent|complete|highlighted|muted")
        }
        let labelPosition: UI2Preview.MetaChip.LabelPosition
        switch item.labelPosition ?? "trailing" {
        case "trailing": labelPosition = .trailing
        case "leading": labelPosition = .leading
        default:
            throw ViewRegistryError.unknownView(
                "component.ui2.C-037: chips[\(index)].labelPosition must be trailing|leading")
        }
        ui2C037Chips.append(.init(value: value, label: item.label, state: state, labelPosition: labelPosition))
    }
    // Seed the photo synchronously so the snapshot's single layout pass can render it —
    // same mechanism and same reason as the C-033 / C-038 / C-054 cases above.
    let ui2C037ImageURL = c.imageURL.flatMap(URL.init(string:))
    if let photoURL = ui2C037ImageURL, photoURL.scheme?.hasPrefix("http") == true,
       let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
        UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
    }
    return declareCase(
        UI2Preview.ListResultRow(
            subject: ui2C037Subject,
            title: ui2C037Title,
            detail: ui2C037Detail,
            description: c.description,
            count: c.count,
            chips: ui2C037Chips,
            trailing: ui2C037Trailing,
            selection: ui2C037Selection,
            imageURL: ui2C037ImageURL,
            initials: c.initials
        ),
        // C-037 deviation 1 (OQ-C-037-5): "the row fills its container; width is not a
        // variant (the sheet's 382 vs consumers' 408 is the sheet cell)" — the consumers'
        // 408 is the master width; width, margin and ground live here.
        PreviewFrame(width: 408)
    )
}


/// `component.ui2.C-091` — the ActivityCanvas preview. Out of line for the same stack-frame reason
/// as C-083.
@MainActor @inline(never)
private func buildUI2C091(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-091: missing state.component")
    }
    // C-091 §4 (R-07): `background`, `mode` and `content` are required — a nil is a fixture bug,
    // not a value to guess. `passage` / `selectedHighlightID` / `deleteTarget` default to nil,
    // `centerGuide` to false; the three callbacks are the view's no-ops.
    let ui2C091Background: UI2Preview.ActivityCanvas<AnyView>.Background
    if c.background?.plain != nil {
        ui2C091Background = .plain
    } else if let image = c.background?.image, let url = URL(string: image.imageURL),
              let wash = ui2C091Hex(image.washColor) {
        // Seed the image synchronously so the snapshot's single layout pass can render it — same
        // mechanism and same reason as the C-033 / C-037 cases. An unreachable URL leaves the
        // canvas on its §2 placeholder base, which is the contract's own until-resolved look.
        if url.scheme?.hasPrefix("http") == true,
           let data = try? Data(contentsOf: url), let picture = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(picture, for: url)
        }
        ui2C091Background = .image(imageURL: url, washColor: wash, washOpacity: image.washOpacity)
    } else {
        throw ViewRegistryError.unknownView("component.ui2.C-091: props.background must be {plain:{}} or {image:{imageURL, washColor #rrggbb, washOpacity}}")
    }
    let ui2C091Mode: UI2Preview.ActivityCanvas<AnyView>.Mode
    switch c.mode {
    case "idle": ui2C091Mode = .idle
    case "editing": ui2C091Mode = .editing
    case "highlighting": ui2C091Mode = .highlighting
    case "manipulating": ui2C091Mode = .manipulating
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-091: props.mode must be idle|editing|highlighting|manipulating")
    }
    var ui2C091Passage: UI2Preview.ActivityCanvas<AnyView>.Passage?
    if let raw = c.passage {
        guard let decoded = try? JSONDecoder().decode(CaptureUI2CanvasPassage.self, from: Data(raw.utf8)) else {
            throw ViewRegistryError.unknownView("component.ui2.C-091: props.passage is not a {verses, highlights} JSON string")
        }
        ui2C091Passage = .init(
            verses: decoded.verses.map { .init(number: $0.number, text: $0.text) },
            highlights: try decoded.highlights.map { h in
                guard h.range.count == 2, h.range[0] <= h.range[1] else {
                    throw ViewRegistryError.unknownView("component.ui2.C-091: highlight \(h.id) range must be [lower, upper]")
                }
                return .init(id: h.id, verse: h.verse, range: h.range[0]..<h.range[1], note: h.note)
            }
        )
    }
    let ui2C091DeleteTarget: UI2Preview.ActivityCanvas<AnyView>.DeleteTarget?
    switch c.deleteTarget {
    case nil: ui2C091DeleteTarget = nil
    case "visible": ui2C091DeleteTarget = .visible
    case "armed": ui2C091DeleteTarget = .armed
    case let other?:
        throw ViewRegistryError.unknownView("component.ui2.C-091: props.deleteTarget \"\(other)\" must be visible|armed")
    }
    guard let ui2C091Children = c.content?.children else {
        throw ViewRegistryError.unknownView("component.ui2.C-091: props.content is required ([] for an empty slot)")
    }
    let ui2C091Slot = try ui2C091Children.enumerated().map { index, child in
        try ui2C091Child(child, index: index)
    }
    // §2 Sizing: the canvas takes the height the screen gives it — 775 (Idle, Highlighting) or
    // 709 (Editing) in the frames — carried in `__frameHeight`.
    guard let ui2C091Height = c.__frameHeight else {
        throw ViewRegistryError.unknownView("component.ui2.C-091: __frameHeight (the canvas height) is required")
    }
    return declareCase(
        UI2Preview.ActivityCanvas<AnyView>(
            background: ui2C091Background,
            mode: ui2C091Mode,
            passage: ui2C091Passage,
            selectedHighlightID: c.selectedHighlightID,
            content: {
                AnyView(ZStack(alignment: .topLeading) {
                    ForEach(Array(ui2C091Slot.enumerated()), id: \.offset) { _, child in child }
                })
            },
            centerGuide: c.centerGuide ?? false,
            deleteTarget: ui2C091DeleteTarget
        )
        // C-092's looping animations rest at phase 1 when animations are off (its own case).
        .transaction { $0.disablesAnimations = true },
        // C-091 §2: 440 wide on the edit frames — the device width, so no page margin (the
        // C-084 precedent); the ground is the canvas's own.
        PreviewFrame(width: 440, height: CGFloat(ui2C091Height), margin: 0)
    )
}

/// One `content` child of C-091, built through its own registry view with its own §4 props and
/// placed where the screen places it.
@MainActor
private func ui2C091Child(_ child: CaptureUI2CanvasChild, index: Int) throws -> AnyView {
    let at = CGPoint(x: child.x ?? 0, y: child.y ?? 0)
    switch child.component {
    case "C-092":
        guard let text = child.text, let size = child.size, let editing = child.editing else {
            throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-092 needs text, size, editing")
        }
        let font: UI2Preview.CanvasTextObject.Font
        switch child.font {
        case "poppins": font = .poppins
        case "sfPro": font = .sfPro
        case "georgia": font = .georgia
        case "typewriter": font = .typewriter
        default:
            throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-092 font must be poppins|sfPro|georgia|typewriter")
        }
        var transform = UI2Preview.CanvasTextObject.Transform.identity
        if let t = child.transform {
            if let p = t.position { transform.position = CGPoint(x: p.x, y: p.y) }
            if let scale = t.scale { transform.scale = scale }
            if let rotation = t.rotation { transform.rotation = .degrees(rotation) }
            transform.width = t.width.map { CGFloat($0) }
        }
        let object = UI2Preview.CanvasTextObject(text: text, font: font, size: CGFloat(size), transform: transform, editing: editing)
        if editing {
            // The edit slot: the screen's x / y / width (§2 layer 4).
            return AnyView(object.frame(width: child.width.map { CGFloat($0) }).offset(x: at.x, y: at.y))
        }
        // A committed object sits at its own transform's centre (C-092 never offsets itself).
        return AnyView(object.frame(width: child.width.map { CGFloat($0) }).position(transform.position))
    case "C-093":
        guard let value = child.value else {
            throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-093 needs value")
        }
        return AnyView(UI2Preview.TextSizeSlider(value: CGFloat(value)).offset(x: at.x, y: at.y))
    case "C-102":
        guard let raw = child.glyph, let glyph = UI2Preview.GlyphName(rawValue: raw),
              let tone = child.tone.flatMap(UI2Preview.IconButton.Tone.init(rawValue:)),
              let style = child.style.flatMap(UI2Preview.IconButton.Style.init(rawValue:)),
              let selected = child.selected, let label = child.accessibilityLabel else {
            throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-102 needs glyph, tone, style, selected, accessibilityLabel")
        }
        return AnyView(
            UI2Preview.IconButton(glyph: glyph, tone: tone, style: style, selected: selected, accessibilityLabel: label)
                .offset(x: at.x, y: at.y)
        )
    case "C-105":
        guard let label = child.label else {
            throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-105 needs label")
        }
        let leading = try child.leadingGlyph.map { raw -> UI2Preview.GlyphName in
            guard let name = UI2Preview.GlyphName(rawValue: raw) else {
                throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)] C-105 leadingGlyph \"\(raw)\" is not a library glyph")
            }
            return name
        }
        return AnyView(UI2Preview.Button(label: label, leadingGlyph: leading).offset(x: at.x, y: at.y))
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-091: content[\(index)].component must be C-092|C-093|C-102|C-105")
    }
}

/// A #rrggbb swatch → Color, without `Color(hex:)` (reserved for Colors.swift).
private func ui2C091Hex(_ raw: String) -> Color? {
    let hex = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
    guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else { return nil }
    return Color(
        red: Double((rgb >> 16) & 0xff) / 255,
        green: Double((rgb >> 8) & 0xff) / 255,
        blue: Double(rgb & 0xff) / 255
    )
}


private func makeUI2ChartDate(_ raw: String?) -> Date? {
    guard let raw else { return nil }
    return ui2ChartDateFormatter.date(from: raw)
}


// SearchField takes a `@FocusState.Binding`, which can't be faked with
// `.constant(_)`, so this tiny wrapper owns real `@FocusState`/`@State` to
// render it statically for capture.
struct CaptureSearchFieldWrapper: View {
    let isActive: Bool
    let searchText: String
    let placeholder: String

    @State private var activeState: Bool
    @State private var textState: String
    @FocusState private var focused: Bool

    init(isActive: Bool, searchText: String, placeholder: String) {
        self.isActive = isActive
        self.searchText = searchText
        self.placeholder = placeholder
        _activeState = State(initialValue: isActive)
        _textState = State(initialValue: searchText)
    }

    var body: some View {
        SearchField(
            isActive: $activeState,
            searchText: $textState,
            isFocused: $focused,
            placeholder: placeholder
        )
    }
}

/// `screen.2.0.request-detail` — the request-detail screen preview. Routed from
/// `buildCaptureView` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenRequestDetail(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.request-detail: missing state.component")
    }
    // A missing field takes this build's `pending` sample (the preview linked to the frozen
    // frame `default`), single-sourced on the screen's State.
    let sample = UI2Preview.RequestDetailScreen.State.pending
    let groupPhotoURL = c.groupPhotoURL ?? sample.groupPhotoURL
    // C-038 photo inside C-037: the fixture names the image by URL and the harness resolves the
    // bytes into the preview module's cache (the home-dashboard seam) — the view performs no I/O.
    if let url = URL(string: groupPhotoURL), url.scheme?.hasPrefix("http") == true,
       UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
       let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
        UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.RequestDetailScreen(
        state: .init(
            phone: c.phone ?? sample.phone,
            requestDate: c.requestDate ?? sample.requestDate,
            requestTime: c.requestTime ?? sample.requestTime,
            groupName: c.groupName ?? sample.groupName,
            groupPhotoURL: groupPhotoURL,
            status: c.status ?? sample.status,
            statusDate: c.statusDate ?? sample.statusDate,
            loading: c.loading ?? sample.loading,
            eventDates: c.eventDates ?? sample.eventDates,
            eventTexts: c.eventTexts ?? sample.eventTexts,
            eventHighlights: c.eventHighlights ?? sample.eventHighlights,
            responding: c.responding ?? sample.responding
        )
    ))
}

/// `screen.2.0.enrollment-select-group` — the enrollment-select-group screen preview. Routed
/// from `buildCaptureViewPart10` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenEnrollmentSelectGroup(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-group: missing state.component")
    }
    // A missing field takes this build's `selected` sample (the preview linked to the frozen
    // frame `group-selected`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectGroupScreen.State.selected
    let photoURLs = c.groupPhotoURLs ?? sample.groupPhotoURLs
    // C-038 photos inside C-037: the fixture names each image by URL and the harness resolves the
    // bytes into the preview module's cache (the home-dashboard seam) — the view performs no I/O.
    for raw in photoURLs {
        if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectGroupScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            orgFilterVisible: c.orgFilterVisible ?? sample.orgFilterVisible,
            orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
            leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
            groupNames: c.groupNames ?? sample.groupNames,
            groupPhotoURLs: photoURLs,
            groupLeaderNames: c.groupLeaderNames ?? sample.groupLeaderNames,
            groupMemberCounts: c.groupMemberCounts ?? sample.groupMemberCounts,
            groupEnrollmentCounts: c.groupEnrollmentCounts ?? sample.groupEnrollmentCounts,
            selectedIndex: c.selectedIndex ?? sample.selectedIndex,
            loading: c.loading ?? sample.loading,
            failed: c.failed ?? sample.failed
        )
    ))
}

/// `screen.2.0.enrollment-select-program` — the enrollment program-picker screen preview.
@MainActor @inline(never)
private func buildScreenEnrollmentSelectProgram(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-program: missing state.component")
    }
    // A missing field takes this build's `selected` sample (the preview linked to the frozen
    // frame `program-selected`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectProgramScreen.State.selected
    let coverURLs = c.programCoverURLs ?? sample.programCoverURLs
    // C-038 covers inside C-037: the fixture names each image by URL and the harness resolves the
    // bytes into the preview module's cache (the home-dashboard seam) — the view performs no I/O.
    for raw in coverURLs {
        if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
           UI2Preview.Ui2ImageCache.shared.image(for: url) == nil,
           let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: url)
        }
    }
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectProgramScreen(
        state: .init(
            searchText: c.searchText ?? sample.searchText,
            orgFilterVisible: c.orgFilterVisible ?? sample.orgFilterVisible,
            orgFilterLabel: c.orgFilterLabel ?? sample.orgFilterLabel,
            leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
            programTitles: c.programTitles ?? sample.programTitles,
            programCoverURLs: coverURLs,
            programCreatedLabels: c.programCreatedLabels ?? sample.programCreatedLabels,
            programDayCounts: c.programDayCounts ?? sample.programDayCounts,
            programCompletedCounts: c.programCompletedCounts ?? sample.programCompletedCounts,
            selectedIndex: c.selectedIndex ?? sample.selectedIndex,
            loading: c.loading ?? sample.loading
        )
    ))
}

/// `screen.2.0.enrollment-select-invite-time` — the enrollment invite-time picker screen preview.
@MainActor @inline(never)
private func buildScreenEnrollmentSelectInviteTime(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-invite-time: missing state.component")
    }
    // A missing field takes this build's `set` sample (§3 state 2, the frame `default`'s 07:00),
    // single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectInviteTimeScreen.State.set
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectInviteTimeScreen(
        state: .init(smsTime: c.smsTime ?? sample.smsTime)
    ))
}

/// `screen.2.0.enrollment-select-sync` — the enrollment sync-picker screen preview. Routed from
/// `buildCaptureViewPart10` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenEnrollmentSelectSync(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-sync: missing state.component")
    }
    // A missing field takes this build's `stay-in-sync` sample (the preview linked to the frozen
    // frame `stay-in-sync`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectSyncScreen.State.stayInSync
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectSyncScreen(
        state: .init(syncMode: c.syncMode ?? sample.syncMode)
    ))
}

/// `screen.2.0.enrollment-select-access` — the enrollment accessibility-picker screen preview.
/// Routed from `buildCaptureViewPart10` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenEnrollmentSelectAccess(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-access: missing state.component")
    }
    // A missing field takes this build's `one-at-a-time` sample (the preview linked to the frozen
    // frame `one-at-a-time`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectAccessScreen.State.oneAtATime
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectAccessScreen(
        state: .init(lessonAccess: c.lessonAccess ?? sample.lessonAccess)
    ))
}

/// `screen.2.0.enrollment-select-schedule` — the enrollment schedule-picker screen preview.
/// Routed from `buildCaptureViewPart10` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenEnrollmentSelectSchedule(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.enrollment-select-schedule: missing state.component")
    }
    // A missing field takes this build's `no-start` sample (the preview linked to the frozen
    // frame `date-range`), single-sourced on the screen's State.
    let sample = UI2Preview.EnrollmentSelectScheduleScreen.State.noStart
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    return AnyView(UI2Preview.EnrollmentSelectScheduleScreen(
        state: .init(
            programChosen: c.programChosen ?? sample.programChosen,
            lessonCount: c.lessonCount ?? sample.lessonCount,
            today: c.today?.stringValue ?? sample.today,
            startDate: c.startDate ?? sample.startDate,
            enabledDays: c.enabledDays?.indices ?? sample.enabledDays,
            overriddenDates: c.overriddenDates ?? sample.overriddenDates,
            existingLessonDates: c.existingLessonDates ?? sample.existingLessonDates,
            prompt: c.prompt ?? sample.prompt
        )
    ))
}

/// `component.ui2.C-127` — C-127 ScheduleSummaryFooter. See the case in `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildUI2C127(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-127: missing state.component")
    }
    // C-127 §4 (R-07): `enabledDays` is required — a nil is a fixture bug, not a value to guess.
    // `dateRange` is `ClosedRange<Date>?` whose nil IS "no start date" (§3 `no-start`), read as
    // C-128 reads `startDate`: a null (or §3's literal "nil") is nil, otherwise §3's own spelling
    // `yyyy-MM-dd...yyyy-MM-dd`. Dates read in the device's time zone (the C-113 formatter), so a
    // start of day never shifts. `onEnabledDaysChange` is the view's no-op default.
    var dateRange: ClosedRange<Date>?
    if let rangeRaw = c.dateRange, rangeRaw != "nil" {
        let ends = rangeRaw.components(separatedBy: "...")
        guard ends.count == 2,
              let start = ui2C113DateFormatter.date(from: ends[0]),
              let end = ui2C113DateFormatter.date(from: ends[1]),
              start <= end else {
            throw ViewRegistryError.unknownView("component.ui2.C-127: props.dateRange \"\(rangeRaw)\" is not yyyy-MM-dd...yyyy-MM-dd")
        }
        dateRange = start...end
    }
    guard let enabledRaw = c.enabledDays else {
        throw ViewRegistryError.unknownView("component.ui2.C-127: props.enabledDays is required (weekday names)")
    }
    let weekdays = UI2Preview.ScheduleSummaryFooter.Weekday.allCases
    let enabledDays = Set(try enabledRaw.map { index -> UI2Preview.ScheduleSummaryFooter.Weekday in
        guard weekdays.indices.contains(index) else {
            throw ViewRegistryError.unknownView("component.ui2.C-127: props.enabledDays has an index outside 0…6")
        }
        return weekdays[index]
    })
    return declareCase(
        UI2Preview.ScheduleSummaryFooter(dateRange: dateRange, enabledDays: enabledDays),
        // C-127 §1: the frozen raster is 440×94 — the footer's 320-wide row centred in the full
        // device width, with the screen's 16pt inset (page margin) on every side.
        PreviewFrame(width: 408)
    )
}

/// `component.ui2.C-125` — C-125 EnrollmentProgressHeader. See the case in `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildUI2C125(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-125: missing state.component")
    }
    // C-125 §4 (R-07): `completedSteps` and `totalSteps` are required — a nil is a fixture bug,
    // not a value to guess. `groupName`, `groupImageURL` and `groupInitials` are optional types
    // whose nil is meaningful (no group / no photo / no initials).
    guard let completedSteps = c.completedSteps else {
        throw ViewRegistryError.unknownView("component.ui2.C-125: props.completedSteps is required")
    }
    guard let totalSteps = c.totalSteps else {
        throw ViewRegistryError.unknownView("component.ui2.C-125: props.totalSteps is required")
    }
    let groupImageURL = c.groupImageURL.flatMap(URL.init(string:))
    // Seed the photo synchronously so the snapshot's single layout pass can render it —
    // same mechanism and same reason as the C-038 case.
    if let photoURL = groupImageURL, photoURL.scheme?.hasPrefix("http") == true,
       UI2Preview.Ui2ImageCache.shared.image(for: photoURL) == nil,
       let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
        UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
    }
    return declareCase(
        UI2Preview.EnrollmentProgressHeader(
            groupName: c.groupName,
            groupImageURL: groupImageURL,
            groupInitials: c.groupInitials,
            completedSteps: completedSteps,
            totalSteps: totalSteps
        ),
        // C-125 §2: "full width (376 in every design)"; height intrinsic (287).
        PreviewFrame(width: 376)
    )
}

/// `component.ui2.C-123` — C-123 TaskDisc. See the case in `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildUI2C123(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-123: missing state.component")
    }
    // C-123 §4 (R-07): `look` is required — a nil is a fixture bug, not a value to guess. Each
    // case's associated values are required too, except `photo`'s `imageURL`, whose nil IS the
    // unresolved look (OQ-C-123-001).
    guard let raw = c.look else {
        throw ViewRegistryError.unknownView("component.ui2.C-123: props.look is required")
    }
    func need(_ value: String?, _ label: String) throws -> String {
        guard let value else {
            throw ViewRegistryError.unknownView("component.ui2.C-123: look.\(label) is required for kind \(raw.kind)")
        }
        return value
    }
    let look: UI2Preview.TaskDisc.Look
    switch raw.kind {
    case "glyph":
        let name = try need(raw.glyph, "glyph")
        guard let glyph = UI2Preview.GlyphName(rawValue: name) else {
            throw ViewRegistryError.unknownView("component.ui2.C-123: look.glyph \"\(name)\" is not a library glyph")
        }
        look = .glyph(glyph)
    case "check":
        look = .check
    case "photo":
        let imageURL = raw.imageURL.flatMap(URL.init(string:))
        // Seed the photo synchronously so the snapshot's single layout pass can render it —
        // same mechanism and same reason as the C-038 case.
        if let photoURL = imageURL, photoURL.scheme?.hasPrefix("http") == true,
           UI2Preview.Ui2ImageCache.shared.image(for: photoURL) == nil,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        look = .photo(imageURL: imageURL)
    case "date":
        guard let today = raw.today else {
            throw ViewRegistryError.unknownView("component.ui2.C-123: look.today is required for kind date")
        }
        look = .date(weekday: try need(raw.weekday, "weekday"), month: try need(raw.month, "month"),
                     day: try need(raw.day, "day"), today: today)
    case "time":
        look = .time(time: try need(raw.time, "time"), period: try need(raw.period, "period"))
    case "syncOn":
        look = .syncOn
    case "syncOff":
        look = .syncOff
    case "all":
        look = .all
    case "one":
        look = .one
    default:
        throw ViewRegistryError.unknownView("component.ui2.C-123: look.kind \"\(raw.kind)\" is not a §4 case")
    }
    return declareCase(
        UI2Preview.TaskDisc(look: look),
        // C-123 §2: the disc states its own 64×64 size — it hugs its content, no master width.
        PreviewFrame(alignment: .leading, intrinsic: true)
    )
}

/// `component.ui2.C-124` — C-124 ChecklistStepRow. See the case in `buildCaptureViewPart10`.
@MainActor @inline(never)
private func buildUI2C124(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("component.ui2.C-124: missing state.component")
    }
    // C-124 §4: `disc`, `title`, `description` and `status` are required — a nil is a fixture
    // bug, not a value to guess. `onTap` takes R-03's no-op default.
    guard let raw = c.disc else {
        throw ViewRegistryError.unknownView("component.ui2.C-124: props.disc is required")
    }
    guard let title = c.title else {
        throw ViewRegistryError.unknownView("component.ui2.C-124: props.title is required")
    }
    guard let description = c.description else {
        throw ViewRegistryError.unknownView("component.ui2.C-124: props.description is required")
    }
    guard let rawStatus = c.status, let status = UI2Preview.ChecklistStepRow.Status(rawValue: rawStatus) else {
        throw ViewRegistryError.unknownView("component.ui2.C-124: props.status must be todo | done")
    }
    return declareCase(
        UI2Preview.ChecklistStepRow(
            disc: try decodeUI2TaskDiscLook(raw, key: "component.ui2.C-124", prop: "disc"),
            title: title,
            description: description,
            status: status
        ),
        // C-124 §2: "fills the width it is given (408 in the frame)".
        PreviewFrame(width: 408)
    )
}

/// C-123 §4 `TaskDisc.Look` from its fixture encoding (`{"kind": "<case>", …}`) — the same
/// decoding `buildUI2C123` does inline, for a consumer that passes the look through (C-124 `disc`).
@MainActor
private func decodeUI2TaskDiscLook(_ raw: CaptureUI2TaskDiscLook, key: String, prop: String) throws -> UI2Preview.TaskDisc.Look {
    func need(_ value: String?, _ label: String) throws -> String {
        guard let value else {
            throw ViewRegistryError.unknownView("\(key): \(prop).\(label) is required for kind \(raw.kind)")
        }
        return value
    }
    switch raw.kind {
    case "glyph":
        let name = try need(raw.glyph, "glyph")
        guard let glyph = UI2Preview.GlyphName(rawValue: name) else {
            throw ViewRegistryError.unknownView("\(key): \(prop).glyph \"\(name)\" is not a library glyph")
        }
        return .glyph(glyph)
    case "check":
        return .check
    case "photo":
        let imageURL = raw.imageURL.flatMap(URL.init(string:))
        // Seed the photo synchronously so the snapshot's single layout pass can render it —
        // same mechanism and same reason as the C-038 / C-123 cases.
        if let photoURL = imageURL, photoURL.scheme?.hasPrefix("http") == true,
           UI2Preview.Ui2ImageCache.shared.image(for: photoURL) == nil,
           let data = try? Data(contentsOf: photoURL), let image = UIImage(data: data) {
            UI2Preview.Ui2ImageCache.shared.seed(image, for: photoURL)
        }
        return .photo(imageURL: imageURL)
    case "date":
        guard let today = raw.today else {
            throw ViewRegistryError.unknownView("\(key): \(prop).today is required for kind date")
        }
        return .date(weekday: try need(raw.weekday, "weekday"), month: try need(raw.month, "month"),
                     day: try need(raw.day, "day"), today: today)
    case "time":
        return .time(time: try need(raw.time, "time"), period: try need(raw.period, "period"))
    case "syncOn":
        return .syncOn
    case "syncOff":
        return .syncOff
    case "all":
        return .all
    case "one":
        return .one
    default:
        throw ViewRegistryError.unknownView("\(key): \(prop).kind \"\(raw.kind)\" is not a C-123 §4 case")
    }
}

/// `screen.2.0.groups-enroll-program` — the Enrollment checklist screen preview. Routed from
/// `buildCaptureViewPart10` (out of line for the same stack-frame reason as C-083).
@MainActor @inline(never)
private func buildScreenGroupsEnrollProgram(_ fixture: CaptureFixture) throws -> AnyView {
    guard let c = fixture.state?.component else {
        throw ViewRegistryError.unknownView("screen.2.0.groups-enroll-program: missing state.component")
    }
    // A missing field takes this build's `empty` sample (§3's first state, 0/6), single-sourced
    // on the screen's State.
    let sample = UI2Preview.GroupsEnrollProgramScreen.State.empty
    // The canvas is the harness's (CaptureRunner's `screen.*` branch): devices[0]'s width ×
    // max(its height, the content's length), under the top safe area — the bare screen here.
    // C-109 renders settled in captures (§4: `animated` false in capture).
    return AnyView(UI2Preview.GroupsEnrollProgramScreen(
        state: .init(
            phase: c.phase ?? sample.phase,
            groupName: c.groupName ?? sample.groupName,
            groupInitials: c.groupInitials ?? sample.groupInitials,
            groupImageURL: c.groupImageURL ?? sample.groupImageURL,
            groupCreatedOn: c.groupCreatedOn ?? sample.groupCreatedOn,
            groupActiveMembers: c.groupActiveMembers ?? sample.groupActiveMembers,
            programName: c.programName ?? sample.programName,
            programDescription: c.programDescription ?? sample.programDescription,
            programImageURL: c.programImageURL ?? sample.programImageURL,
            scheduleStartWeekday: c.scheduleStartWeekday ?? sample.scheduleStartWeekday,
            scheduleStartMonth: c.scheduleStartMonth ?? sample.scheduleStartMonth,
            scheduleStartDay: c.scheduleStartDay ?? sample.scheduleStartDay,
            scheduleStartToday: c.scheduleStartToday ?? sample.scheduleStartToday,
            scheduleWeekdays: c.scheduleWeekdays ?? sample.scheduleWeekdays,
            scheduleEndDate: c.scheduleEndDate ?? sample.scheduleEndDate,
            smsTime: c.smsTime ?? sample.smsTime,
            syncMode: c.syncMode ?? sample.syncMode,
            lessonAccess: c.lessonAccess ?? sample.lessonAccess
        ),
        confirmationAnimated: false
    ))
}
