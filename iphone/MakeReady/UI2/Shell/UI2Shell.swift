import SwiftUI

/// SPEC D11: the shell owns the app chrome; roots render content only.
///
/// Placement (built from the contracts per F2's 2026-10-25 ruling, re-checked when the d2m
/// `shell-topnav` / `shell-tabs` specs land):
/// - TopNav is pinned under the status bar (home-dashboard §2: "collapsed nav row (32pt,
///   C-019) pinned at top → scrolling content"); as it morphs 32→96 the content below is
///   pushed down in step (analysis §1 / §3 step 2).
/// - TabBar is pinned to the screen's bottom edge OVER the bottom safe area: its 84pt includes
///   the home-indicator clearance (C-084 §2 Placement, OQ-C-083-2).
/// ui2-members-browse D1: each tab is its own NavigationStack; paths live in UI2ShellModel.paths.
struct UI2Shell: View {
    @State private var model = UI2ShellModel()
    @Environment(AuthManager.self) private var authManager
    /// members-search-pinned: the keyboard's height and the TabBar's, so the page is padded by
    /// only the part of the keyboard that rises past the TabBar it covers.
    @State private var keyboardHeight: CGFloat = 0
    /// Starts at C-084 §2's 84 (the cells' height) so the first frame lays pages out above it.
    @State private var tabBarHeight: CGFloat = 84
    /// action-menu-overlay: the TabBar's Add (+) menu is open.
    @State private var addMenuOpen = false
    /// notes D24: flushes the note save queue when the network comes back.
    @State private var notesConnectivity = NotesConnectivity()
    /// memo-screens D3: the recorder sheet's session while it is up; nil otherwise (D14: one at a time).
    @State private var recorder: RecorderSession?
    /// Voice memo was chosen: the recorder starts once the add menu's slide-out has ended.
    @State private var voiceMemoRequested = false
    /// video-recorder D25: the recorder `model.hostedOverlay` presents; nil otherwise.
    @State private var videoRecorder: VideoRecorderModel?

    /// action-menu-overlay B3: the Add menu's actions, as frame 4717:52460 draws them. B5: none of
    /// their destinations existed in the 2.0 shell at the time. "Invite a member" now opens the invite
    /// flow (invite-member D2), "Write a note" the note editor (notes D17), "Voice memo" the recorder
    /// (memo-screens D2), "Record a video" the video recorder (video-recorder D25).
    static let addMenuActions: [ActionMenuOverlay.ActionItem] = [
        .init(glyph: "c066-record", label: VideoRecorderEntry.rowLabel),
        .init(glyph: "c066-microphone", label: "Voice memo"),
        .init(glyph: "c066-note", label: "Write a note"),
        .init(glyph: "c066-send-alt", label: "Invite a member"),
    ]

    /// members-search-pinned: the keyboard covers the TabBar instead of lifting it.
    static func keyboardOverlap(keyboardHeight: CGFloat, tabBarHeight: CGFloat) -> CGFloat {
        max(0, keyboardHeight - tabBarHeight)
    }

    /// image-framing-editor (owner walk 2026-10-27): a page's bottom edge never depends on whether
    /// the TabBar shows — the TabBar is a layer over the pages, and a page reserves the bar's height
    /// itself, so the bar sliding away moves nothing. Each tab's NavigationStack already insets its
    /// pages by the home-indicator safe area (`safeBottom`, measured on device: 34pt, whatever its
    /// SwiftUI parents ignore), so a page adds only the rest of the bar's 84 — and a full-screen page
    /// nothing: the stack's inset is its home-indicator clearance. A keyboard takes over that inset
    /// (measured, agent walk round 3: a 344 keyboard ends the page 344 + this padding above the bottom)
    /// and covers the bar it would reserve for, so a page ends at the higher of the bar and the keyboard.
    static func pageBottomPadding(fullScreen: Bool, tabBarHeight: CGFloat, safeBottom: CGFloat,
                                  keyboardHeight: CGFloat = 0) -> CGFloat {
        fullScreen ? 0 : max(0, max(tabBarHeight, keyboardHeight) - max(safeBottom, keyboardHeight))
    }

    /// master-search R1: the page each tab's root renders, named so a test can read it.
    enum RootPage: Equatable { case home, empty, search, profile }

    static func rootPage(for tab: TabBar.Tab) -> RootPage {
        switch tab {
        case .home: .home
        case .calendar: .empty
        case .search: .search
        case .profile: .profile
        }
    }

    /// The window's bottom safe area — the inset each NavigationStack applies to its pages.
    private var safeBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ui2-members-browse D1/D2: one NavigationStack per tab, above the TabBar. Home stays
            // mounted — its TopNav keeps its own scroll position (SPEC D12) and its pushed page
            // survives a tab switch (D2); any other tab mounts while selected (Search pushes, T9).
            ZStack {
                ForEach(UI2ShellModel.tabs, id: \.self) { tab in
                    if tab == .home || tab == model.tab {
                        stack(for: tab)
                            .opacity(tab == model.tab ? 1 : 0)
                            .allowsHitTesting(tab == model.tab)
                            .accessibilityHidden(tab != model.tab)
                    }
                }
            }
            // C-084 §2 Motion: "the selection switches instantly with no animation"; a re-tap
            // with a page pushed pops it (D20, the system pop).
            // image-framing-editor (owner walk 2026-10-27): the image editors are full-screen; the
            // bar is drawn over the pages, so removing it changes no page's layout.
            if model.showsTabBar {
                TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: { addMenuOpen = true })
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tabBarHeight = $0 }
                    // action-menu-overlay: C-066 slides up over every piece of chrome (the host below).
                    .actionMenuPresentation(isPresented: addMenuOpen, onDismiss: { addMenuOpen = false },
                                            onHidden: startRequestedRecorder) {
                        ActionMenuOverlay(
                            actions: Self.addMenuActions,
                            onSelect: { action in
                                addMenuOpen = false
                                switch action.label {
                                case InviteEntry.rowLabel: InviteEntry.open(on: model.tab, model: $model)
                                case NoteEntry.rowLabel: NoteEntry.open(on: model.tab, model: $model)  // notes D17
                                case MemoEntry.rowLabel:  // memo-screens D2, D14
                                    voiceMemoRequested = MemoEntry.shouldStart(recorderPresented: recorder != nil)
                                case VideoRecorderEntry.rowLabel: openVideoRecorder()  // video-recorder D25
                                default: break
                                }
                            },
                            showsDone: false,
                            hairlineAfterLast: false
                        )
                    }
                    // C-084 §2 Placement: the 84pt bar includes the home-indicator clearance and sits flush
                    // on the screen's bottom edge. As a layer it would be placed inside the safe area,
                    // its fill running on below it (118pt) — so it ignores that edge itself.
                    .ignoresSafeArea(.container, edges: .bottom)
                    .transition(.move(edge: .bottom))
            }
        }
        // The TabBar slides out under an editor's push and back in on its pop, on the push's timing.
        .animation(Motion.standard, value: model.showsTabBar)
        // memo-screens D2, D3: the recorder sheet rises over the whole shell; the host keeps one overlay.
        .hostedOverlay(recorder.map { session in
            UI2HostedOverlay(view: AnyView(RecorderSheetContainer(session: session, onEnd: recorderEnded)),
                             transition: .identity)
        })
        // video-recorder D25: the recorder covers the whole shell; it shows once the add menu has slid out.
        .hostedOverlay(model.hostedOverlay == .videoRecorder ? videoRecorder.map { recorder in
            UI2HostedOverlay(view: AnyView(VideoRecorderOverlay(model: recorder, onEnd: videoRecorderEnded)),
                             transition: .identity)
        } : nil)
        .ignoresSafeArea(.container, edges: .bottom)
        // filter-menu-fullscreen: full-screen menus (C-036) draw here, above TopNav and TabBar.
        .ui2OverlayHost()
        // invite-member Fixes (E6): surfaced errors (`recordError(surface: true)`) draw above everything.
        .overlay(alignment: .top) { UI2ErrorBannerHost() }
        // members-search-pinned: the keyboard never lifts the TabBar (it squeezed the Members
        // list); the pages above it get the keyboard's overlap as safe area instead.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            followKeyboard(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            followKeyboard(note, hiding: true)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task {
            PushNotificationManager.shared.clearPendingDeepLink()  // SPEC D17
            await AppState.shared.loadInitialData()                 // SPEC D24
            // notes D24: unsent note saves go out on launch, and each time the network returns.
            notesConnectivity.start(queue: .shared)
            _ = await NoteSaveQueue.shared.flush()
        }
        // SPEC D17: release 1 has no deep-link consumer, so a link set while the shell is
        // mounted (a push tap, a URL, a file open) is dropped rather than left to fire later.
        // Remove when the first 2.0 deep-link consumer lands.
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, link in
            if link != .none { PushNotificationManager.shared.clearPendingDeepLink() }
        }
        // ui2-enrollment-create D13: a checklist that left every stack (swipe-back, Home re-tap)
        // takes its LOCAL draft with it. ui2-enrollments-browse D2/R4/D30: once its save in flight
        // has settled — a saved draft stays on the server; the prune never DELETEs.
        .onChange(of: model.enrollmentFlowIds) { _, ids in
            EnrollDraftSyncs.prune(keeping: ids)
        }
    }

    /// memo-screens D3: the add menu has slid out, so the recorder can be the one hosted overlay.
    private func startRequestedRecorder() {
        guard voiceMemoRequested else { return }
        voiceMemoRequested = false
        guard MemoEntry.shouldStart(recorderPresented: recorder != nil),
              let userId = authManager.currentUser?.id else { return }
        // C-016 slides itself in on appear and out before `onEnd` (a hosted overlay gets no
        // presenting transaction — ActionMenuLayer's rule), so no animation here.
        recorder = MemoEntry.makeSession(userId: userId)
    }

    /// video-recorder D25: the host keeps the add menu until it has slid out, then shows the recorder.
    private func openVideoRecorder() {
        guard videoRecorder == nil, recorder == nil, let userId = authManager.currentUser?.id else { return }
        videoRecorder = VideoRecorderModel.live(entry: .plusMenu, userId: userId)
        if videoRecorder != nil { model.onSelect(.recordVideo) }
    }

    private func videoRecorderEnded() {
        model.hostedOverlay = nil
        videoRecorder = nil
    }

    /// memo-screens D7, D11: a saved memo opens its page at once, where the leader names it (owner
    /// 2026-11-21, replacing D6's toast); a discarded or failed one opens nothing.
    private func recorderEnded(_ outcome: RecorderSession.Outcome) {
        recorder = nil
        if case let .saved(localId) = outcome {
            model.push(MemoEntry.viewDestination(localId: localId), on: model.tab)
        }
    }

    /// Only the page on top of its stack follows the keyboard. A page being pushed away (or under
    /// another) keeps its keyboard-down layout, so a pushed page that raises the keyboard at once —
    /// + → Write a note over Library — never squeezes the outgoing page mid-slide (owner 2026-11-22:
    /// Library "shrinks and animates up to the left"). SWIFTUI_TRANSITIONS.md § Keyboard Insets.
    private func keyboard(onTop: Bool) -> CGFloat { onTop ? keyboardHeight : 0 }

    /// members-search-pinned's keyboard overlap (the keyboard covers the TabBar instead of lifting
    /// it), applied per page and only to the top one.
    private func keyboardPadding(onTop: Bool) -> CGFloat {
        Self.keyboardOverlap(keyboardHeight: keyboard(onTop: onTop),
                             tabBarHeight: model.showsTabBar ? tabBarHeight : 0)
    }

    /// members-search-pinned: track the keyboard on its own animation timing.
    private func followKeyboard(_ note: Notification, hiding: Bool = false) {
        let info = note.userInfo
        let frame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let screenHeight = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? frame.maxY
        let height = hiding ? 0 : max(0, screenHeight - frame.minY)
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        withAnimation(.easeOut(duration: duration)) { keyboardHeight = height }
    }

    /// D1: the system bar is hidden on every page (pushed pages draw C-040); the interactive
    /// edge pop is re-armed on the root and on every pushed page (F2). The motion is the system
    /// push — no custom curve, duration or scrim.
    private func stack(for tab: TabBar.Tab) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            root(for: tab)
                .ui2PageBottom(Self.pageBottomPadding(fullScreen: false, tabBarHeight: tabBarHeight, safeBottom: safeBottom,
                                                keyboardHeight: keyboard(onTop: model.path(for: tab).isEmpty)))
                .safeAreaPadding(.bottom, keyboardPadding(onTop: model.path(for: tab).isEmpty))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .background(UI2InteractivePop())
                .navigationDestination(for: UI2Destination.self) { destination in
                    UI2PushedPage {                            // group-cover-image D26: + its back-swipe guard
                        page(for: destination)
                            .ui2PageBottom(Self.pageBottomPadding(fullScreen: destination.isFullScreen,
                                                                     tabBarHeight: tabBarHeight, safeBottom: safeBottom,
                                                                     keyboardHeight: keyboard(onTop: model.path(for: tab).last == destination)))
                            .safeAreaPadding(.bottom, keyboardPadding(onTop: model.path(for: tab).last == destination))
                    }
                }
        }
        .environment(\.ui2Navigator, UI2Navigator.bound(to: $model, tab: tab))
        // dashboard-chart-intros D15: the dashboard resets its intros while hidden, replays on return.
        .environment(\.chartIntroActive, model.homeActive)
    }

    private func pathBinding(for tab: TabBar.Tab) -> Binding<[UI2Destination]> {
        Binding(get: { model.path(for: tab) }, set: { model.setPath($0, for: tab) })
    }

    /// A tab's root page. Home's root is the TopNav + section page (D1: the stack wraps
    /// `HomeSectionLayout`, so TopNav slides left with the root under a push).
    @ViewBuilder private func root(for tab: TabBar.Tab) -> some View {
        switch Self.rootPage(for: tab) {
        case .home: HomeSectionLayout(model: $model) { sectionContent }
        case .empty: EmptyPage()
        case .search: SearchHomeContainer()  // master-search R1
        case .profile: ProfileStopgapContainer()
        }
    }

    @ViewBuilder private func page(for destination: UI2Destination) -> some View {
        switch destination {
        case let .inviteDetail(id): InviteDetailContainer(id: id)
        case let .requestDetail(id): RequestDetailContainer(id: id)
        case let .memberDetail(id, name): MemberDetailHost(id: id, name: name)
        case let .editMemberField(memberId, field): MemberFieldEditContainer(memberId: memberId, field: field)  // ui2-members-edit D2
        case let .inviteSelectGroup(returnDepth): InviteSelectGroupContainer(returnDepth: returnDepth)  // invite-member D3
        case let .inviteMember(groupId, returnDepth): InviteMemberContainer(groupId: groupId, returnDepth: returnDepth)  // invite-member D1
        case let .groupDetail(id, name): GroupDetailHost(id: id, name: name)                 // ui2-groups-browse D1
        case let .editGroupField(groupId, field): GroupFieldEditContainer(groupId: groupId, field: field)  // ui2-groups-edit D2
        case .createGroup:                                                                    // ui2-groups-browse D1/D8
            CreateGroupContainer(route: .createGroup, destination: { .groupDetail(id: $0.id, name: $0.name) })
        case let .editGroupCover(groupId, source): EditGroupCoverContainer(groupId: groupId, source: source)  // group-cover-image D4
        case let .editMemberAvatar(memberId, source): EditMemberAvatarContainer(memberId: memberId, source: source)  // image-framing-editor D9
        // ui2-programs D1: the program pages land in Tasks 11–15.
        case let .studyProgramHome(id, name): StudyProgramHomeHost(id: id, name: name)          // ui2-programs D1
        case .createStudyProgram: CreateStudyProgramContainer()                               // ui2-programs D1/D8
        case let .editProgramField(programId, field): ProgramFieldEditContainer(programId: programId, field: field)  // ui2-programs D10
        case let .editProgramCover(programId, source): EditProgramCoverContainer(programId: programId, source: source)  // ui2-programs D11
        case let .enrollmentHome(id, name): EnrollmentHomeHost(id: id, name: name)               // ui2-enrollments-browse R2
        case let .enrollChecklist(flowId): EnrollChecklistContainer(flowId: flowId)                 // ui2-enrollment-create D2
        case let .enrollSelectGroup(flowId): EnrollSelectGroupContainer(flowId: flowId)
        case let .enrollSelectProgram(flowId): EnrollSelectProgramContainer(flowId: flowId)
        case let .enrollSelectSchedule(flowId): EnrollSelectScheduleContainer(flowId: flowId)
        case let .enrollSelectInviteTime(flowId): EnrollSelectInviteTimeContainer(flowId: flowId)
        case let .enrollSelectSync(flowId): EnrollSelectSyncContainer(flowId: flowId)
        case let .enrollSelectAccess(flowId): EnrollSelectAccessContainer(flowId: flowId)
        case let .chooseCoverFromLibrary(owner): MediaHomeContainer(mode: .pick(owner))  // media-library D9
        case .mediaHome: MediaHomeContainer(mode: .pushed)   // master-search D9: a video result's exit
        case .programsHome: ProgramsHomeHost()                // master-search D27: a template result's exit
        case let .activityNew(programId, lessonId): ActivityNewContainer(programId: programId, lessonId: lessonId)  // program-lesson-add-activity D2
        case let .activitiesEditor(activityId): ActivitiesEditorContainer(activityId: activityId)  // text-activity D39
        case let .activityViewer(lessonVersionId, activityId):
            ActivityViewerContainer(lessonVersionId: lessonVersionId, activityId: activityId)  // text-activity D39
        case let .chooseActivityBackground(activityId): MediaHomeContainer(mode: .pickActivityBackground(activityId: activityId))  // D40
        // bible-verse-picker D2: the four picker pages.
        case let .bibleBooks(flowId): BibleBooksContainer(flowId: flowId)
        case let .bibleChapters(book, flowId): BibleChaptersContainer(book: book, flowId: flowId)
        case let .bibleVerses(book, chapter, flowId): BibleVersesContainer(book: book, chapter: chapter, flowId: flowId)
        case let .bibleReader(book, chapter, verse, flowId): BibleReaderContainer(book: book, chapter: chapter, verse: verse, flowId: flowId)
        // notes D17: the editor on a fresh note (a new flowId per open) or a stored one.
        case let .newNote(flowId): NoteEditorContainer(noteId: nil).id(flowId)
        case let .noteEditor(noteId): NoteEditorContainer(noteId: noteId).id(noteId)
        case let .memoDetail(memoId): MemoDetailContainer(memoId: memoId).id(memoId)  // memo-screens D4
        case let .videoDetail(id): VideoDetailContainer(videoId: id).id(id)  // video-recorder D16
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: HomeDashboardContainer()  // SPEC D8/D13
        case .members: MembersHomeContainer() // ui2-members-browse
        case .groups: GroupsHomeContainer(destination: { .groupDetail(id: $0, name: $1) })  // ui2-groups-browse D1/D3
        case .programs: StudyProgramsContainer(destination: { .studyProgramHome(id: $0, name: $1) })  // ui2-programs D1/D3
        case .enrollments: EnrollmentsHomeContainer()  // ui2-enrollments-browse R1
        case .invites: InvitesHomeContainer(onOpen: { model.push(.invitation($0), on: .home) })
        case .media: MediaHomeContainer(addRequest: model.mediaAddRequest)  // media-page D1, media-library D13
        case .library: LibraryHomeContainer()  // library-home §7
        }
    }
}

extension View {
    /// The space a page leaves below itself in its tab's NavigationStack: page background, since the
    /// stack's own is the window's white wherever the TabBar does not cover it (agent walk round 3).
    func ui2PageBottom(_ padding: CGFloat) -> some View {
        self.padding(.bottom, padding)
            .background(Token.layoutBackground.ignoresSafeArea())
    }
}
