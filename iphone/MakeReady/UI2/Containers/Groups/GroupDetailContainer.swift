import PhotosUI
import SwiftUI

/// ui2-groups-browse §iphone Group page: the pushed `.groupDetail` page (D1, D4). It owns its
/// ScrollView and pins C-040 above it (D27: the screen's `showsHeader: false`, the
/// MemberProfileContainer precedent). Cache-first: the stores render at once under the pushed
/// name, and eight loads run in parallel; a failure keeps what is shown (D4) and a group outside
/// the caller's scope just stays empty (D23).
struct GroupDetailContainer: View {
    let groupId: String
    let name: String

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe (D17).
    @State private var imagesSeeded = 0
    /// ui2-groups-edit D9: the Delete Group menu is up.
    @State private var deleteMenuOpen = false
    /// group-cover-image D1/D3: the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D2: the cover menu, and the row chosen in it — acted on once the menu has slid out (D8).
    @State private var coverMenuOpen = false
    @State private var pendingCoverChoice: CoverChoice?
    /// D8: the viewer's URL while it is up.
    @State private var viewerURL: String?

    var body: some View {
        let output = GroupDetailMapper.output(Self.input(groupId: groupId, name: name, state: AppState.shared),
                                              now: Date(), timeZone: .current)
        let _ = imagesSeeded
        // D17: the screen reads images only from Ui2ImageCache, so an image reaches it once cached
        // and its arrival changes the screen's input.
        let state = Self.cachedImages(output.state)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: state.groupName,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }       // groups-detail §3: back pops to the pusher
            )
            ScrollView(.vertical) {
                GroupsDetailScreen(
                    state: state,
                    showsHeader: false,
                    // ui2-groups-edit D1: a settings row → that field's edit page.
                    onEditField: { label in
                        guard let next = Self.editDestination(groupId: groupId, label: label,
                                                              group: AppState.shared.groups[groupId]) else { return }
                        navigator.push(next)
                    },
                    // D7: Members `add` → invite; Cancel/Done return here.
                    onInviteMember: { navigator.push(.inviteMember(groupId: groupId, returnDepth: navigator.depth())) },
                    // D7: a member row → the member page (GroupMember.userId). D6: everything else inert.
                    onOpenMember: { row in
                        guard let member = output.member(atRow: row) else { return }
                        navigator.push(.memberDetail(id: member.id, name: member.name))
                    },
                    // ui2-groups-edit D9: C-048 Delete Group → the C-066 confirmation.
                    onDeleteGroup: { deleteMenuOpen = true },
                    // group-cover-image D1/D2: no cover → the picker; a cover → Change · Edit · View.
                    onCoverTap: { handleCoverTap() }
                )
            }
            .scrollIndicators(.hidden)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        // ui2-groups-edit D9/D14: one red row and Done, nothing else; Done = cancel. Hosted by the
        // shell's `.ui2OverlayHost()`, like the Add menu.
        .actionMenuPresentation(isPresented: deleteMenuOpen, onDismiss: { deleteMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [Self.deleteAction(groupName: state.groupName)],
                onSelect: { _ in
                    deleteMenuOpen = false
                    Task { await deleteGroup() }
                },
                onDone: { deleteMenuOpen = false }
            )
        }
        // group-cover-image D2: Change · Edit · View; Done cancels. The chosen row runs after the
        // menu has finished hiding — the overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: coverMenuOpen, onDismiss: { coverMenuOpen = false },
                                onHidden: { runPendingCoverChoice() }) {
            ActionMenuOverlay(
                actions: Self.coverActions,
                onSelect: { item in
                    pendingCoverChoice = CoverChoice(label: item.label)
                    coverMenuOpen = false
                },
                onDone: { coverMenuOpen = false }
            )
        }
        // D1/D3: the system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        // D8
        .coverViewerPresentation(url: viewerURL, accessibilityLabel: "Group cover", onClose: { viewerURL = nil })
        .task { await Self.load(groupId: groupId, authManager: authManager) }
        .task(id: Self.imageURLs(output.state)) {
            if await UI2ImageLoader.seed(Self.imageURLs(output.state), context: "GroupDetailContainer") { imagesSeeded += 1 }
        }
        .task(id: output.state.programCoverURLs) {
            if await CoverImageLoader.seedList(output.state.programCoverURLs) { imagesSeeded += 1 }
        }
    }

    enum CoverTap: Equatable { case none, picker, menu }

    enum CoverChoice: String {
        case change = "Change image", edit = "Edit image", view = "View image"
        init?(label: String) { self.init(rawValue: label) }
    }

    /// group-cover-image D2: the menu rows — Edit · Change · View (order: owner 2026-10-27,
    /// image-framing-editor D4) — existing glyphs (an unknown name renders the red stub).
    static let coverActions: [ActionMenuOverlay.ActionItem] = [
        .init(glyph: "edit", label: CoverChoice.edit.rawValue),
        .init(glyph: "upload", label: CoverChoice.change.rawValue),
        .init(glyph: "eye", label: CoverChoice.view.rawValue)
    ]

    /// D1/D2/F7: read from AppState's group — inert until it has loaded.
    static func coverTap(group: UserGroup?) -> CoverTap {
        guard let group else { return .none }
        return (group.coverImageUrl ?? "").isEmpty ? .picker : .menu
    }

    private func handleCoverTap() {
        switch Self.coverTap(group: AppState.shared.groups[groupId]) {
        case .none: break
        case .picker: pickerOpen = true
        case .menu: coverMenuOpen = true
        }
    }

    private func runPendingCoverChoice() {
        guard let choice = pendingCoverChoice else { return }
        pendingCoverChoice = nil
        switch choice {
        case .change: pickerOpen = true
        case .edit: navigator.push(.editGroupCover(groupId: groupId, source: .stored))
        case .view: viewerURL = AppState.shared.groups[groupId].flatMap(CoverViewerOverlay.viewerURL(group:))
        }
    }

    /// D3/D6: load the pick, make it upright and ≤ 2400px, then Edit cover. Dismissing the picker
    /// changes nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(.editGroupCover(groupId: groupId, source: .newPick(image)))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "GroupDetailContainer.openPicked", surface: true,
                                        friendlyMessage: "Couldn't open that photo")
        }
    }

    /// ui2-groups-edit D9/D13: the menu's one row.
    static func deleteAction(groupName: String) -> ActionMenuOverlay.ActionItem {
        .init(glyph: "trash-2", label: "Delete \(groupName)", tone: .destructive)
    }

    /// ui2-groups-edit D9: the banner a failed delete shows; the page stays.
    static let deleteFailedMessage = "Couldn't delete the group"

    /// D9/D10: delete, then the Groups stack back to its root (the Groups list, without the group).
    @MainActor
    private func deleteGroup() async {
        do {
            try await GroupActions().deleteGroup(id: groupId)
            navigator.popTo(0)
        } catch {
            if GroupActions.isCancellation(error) { return }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "GroupDetailContainer.signOut", surface: false)
                }
                return
            }
            AppState.shared.recordError(error, context: "GroupDetailContainer.deleteGroup", surface: true,
                                        friendlyMessage: Self.deleteFailedMessage,
                                        retry: { Task { await deleteGroup() } })
        }
    }

    /// D4: every group store, read for this group.
    @MainActor
    static func input(groupId: String, name: String, state app: AppState) -> GroupDetailMapper.Input {
        GroupDetailMapper.Input(
            name: name,
            group: app.groups[groupId],
            members: app.membersFor(groupId: groupId),
            requests: app.pendingJoinRequestsByGroupId[groupId] ?? [],
            enrollments: app.enrollmentsFor(groupId: groupId),
            nextStudy: app.nextStudyByGroupId[groupId],
            history: app.historyByGroupId[groupId] ?? [],
            days: app.groupDaysByGroupId[groupId],
            chart: app.groupChartByGroupId[groupId]
        )
    }

    /// ui2-groups-edit D1: the row label's edit page — nil for an unknown label, or while the
    /// group has not loaded (the page has nothing to edit yet).
    static func editDestination(groupId: String, label: String, group: UserGroup?) -> UI2Destination? {
        guard group != nil, let field = GroupField(label: label) else { return nil }
        return .editGroupField(groupId: groupId, field: field)
    }

    /// D17: the full-size images the container seeds — the cover and the lesson slides. The
    /// enrollment rows' program covers are list copies (cover-image-sizes, CoverImageLoader).
    static func imageURLs(_ state: GroupsDetailScreen.State) -> [String] {
        ([state.coverURL] + state.lessonSlideImages.flatMap { $0 }).filter { !$0.isEmpty }
    }

    /// Each image URL already in Ui2ImageCache, else "" (the component's empty look until it lands).
    @MainActor
    static func cachedImages(_ mapped: GroupsDetailScreen.State) -> GroupsDetailScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        s.programCoverURLs = CoverImageLoader.cachedListURLs(mapped.programCoverURLs)
        return s
    }

    /// D4: the eight section loads, all at once.
    @MainActor
    static func load(groupId: String, authManager: AuthManager) async {
        let onUnauthorized: @MainActor () async -> Void = { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "GroupDetailContainer.signOut", surface: false)
            }
        }
        let groups = GroupActions(onUnauthorized: onUnauthorized)
        async let group: () = attempt("getGroup", onUnauthorized: onUnauthorized) { _ = try await groups.getGroup(id: groupId) }
        async let members: () = attempt("loadMembers", onUnauthorized: onUnauthorized) { _ = try await groups.loadMembers(groupId: groupId) }
        async let requests: () = attempt("loadJoinRequests", onUnauthorized: onUnauthorized) { try await groups.loadJoinRequests(groupId: groupId) }
        async let enrollments: () = attempt("loadEnrollments", onUnauthorized: onUnauthorized) {
            _ = try await EnrollmentActions().loadEnrollments(groupId: groupId)
        }
        async let next: () = groups.loadNextStudy(groupId: groupId)
        async let history: () = groups.loadHistory(groupId: groupId)
        async let days: () = groups.loadGroupDays(groupId: groupId)
        async let chart: () = groups.loadGroupChart(groupId: groupId)
        _ = await (group, members, requests, enrollments, next, history, days, chart)
    }

    /// D4/D23 for the four throwing loaders: cancelled → nothing; 401 → sign-out; anything else —
    /// a 404 outside the caller's scope included — console-only, so the page keeps what it shows.
    @MainActor
    static func attempt(_ context: String, state: AppState? = nil, onUnauthorized: @MainActor () async -> Void,
                        _ work: @MainActor () async throws -> Void) async {
        do {
            try await work()
        } catch {
            if GroupActions.isCancellation(error) { return }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return
            }
            (state ?? .shared).recordError(error, context: "GroupDetailContainer.\(context)", surface: false)
        }
    }
}
