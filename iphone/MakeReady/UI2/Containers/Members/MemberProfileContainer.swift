import PhotosUI
import SwiftUI

/// ui2-members-browse §iphone Member page: the pushed `.memberDetail` page (D1). It owns its
/// ScrollView (the screen has no root scroll); C-040 back pops its tab's stack. Cache-first for
/// the session (D21): the stores render at once — the list-known name heads the page while it
/// loads (F5) — and four loads refresh them; a failure keeps what is shown.
struct MemberProfileContainer: View {
    let memberId: String
    let name: String

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when program covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0
    /// image-framing-editor D4: the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D4: the photo menu, its rows, and the row chosen — acted on once the menu has slid out.
    @State private var avatarMenuOpen = false
    @State private var avatarMenuRows: [ActionMenuOverlay.ActionItem] = []
    @State private var pendingAvatarChoice: AvatarChoice?
    /// D13: the viewer's URL while it is up.
    @State private var viewerURL: String?

    var body: some View {
        let app = AppState.shared
        let mapped = MemberProfileMapper.state(
            .init(name: name, detail: app.memberDetails[memberId], groups: app.memberGroupsById[memberId],
                  engagement: app.memberEngagementById[memberId], days: app.memberDaysById[memberId],
                  organizationId: app.organizationId),
            today: Date(), timeZone: .current
        )
        let _ = coversSeeded
        // The screen reads covers from Ui2ImageCache, which SwiftUI does not observe — so a cover
        // reaches it only once cached, and its arrival changes the screen's input (round 1).
        let state = {
            var state = mapped
            state.programCoverURLs = Self.cachedCoverURLs(mapped.programCoverURLs)
            state.fieldsEditable = app.memberDetails[memberId] != nil     // ui2-members-edit D27
            return state
        }()
        // D22: C-040 stays pinned above the scroll; the screen is told not to draw it again.
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: state.memberName,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }    // members-profile §3: back pops to the presenter
            )
            ScrollView(.vertical) {
                MembersProfileScreen(
                    state: state,
                    showsHeader: false,
                    // ui2-members-edit D2: a field row pushes its edit page on this tab's stack.
                    onEditField: { navigator.push(.editMemberField(memberId: memberId, field: $0)) },
                    // ui2-groups-browse D7: a group row opens that group's page. Program rows, both
                    // `add`s and the day cards stay no-ops (browse D5).
                    onOpenGroup: { row in
                        guard let page = Self.groupDestination(app.memberGroupsById[memberId], row: row) else { return }
                        navigator.push(page)
                    },
                    // image-framing-editor D4: no photo → the picker; a photo → Change · Edit · View (Google-only: no Edit).
                    onAvatarTap: { handleAvatarTap() }
                )
            }
            .scrollIndicators(.hidden)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        // D4: the C-066 photo menu; Done cancels. The chosen row runs after the menu has finished
        // hiding — the overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: avatarMenuOpen, onDismiss: { avatarMenuOpen = false },
                                onHidden: { runPendingAvatarChoice() }) {
            ActionMenuOverlay(
                actions: avatarMenuRows,
                onSelect: { item in
                    pendingAvatarChoice = AvatarChoice(label: item.label)
                    avatarMenuOpen = false
                },
                onDone: { avatarMenuOpen = false }
            )
        }
        // D4: the system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        // D13
        .coverViewerPresentation(url: viewerURL, accessibilityLabel: Self.viewerLabel, onClose: { viewerURL = nil })
        .task { await Self.load(memberId: memberId, authManager: authManager) }
        .task(id: mapped.programCoverURLs) {
            if await Self.seedCovers(mapped.programCoverURLs) { coversSeeded += 1 }
        }
    }

    private func handleAvatarTap() {
        let tap = Self.avatarTap(detail: AppState.shared.memberDetails[memberId])
        switch tap {
        case .none: break
        case .picker: pickerOpen = true
        case .menu, .googleMenu:
            avatarMenuRows = Self.avatarActions(tap)
            avatarMenuOpen = true
        }
    }

    private func runPendingAvatarChoice() {
        guard let choice = pendingAvatarChoice else { return }
        pendingAvatarChoice = nil
        switch choice {
        case .change: pickerOpen = true
        case .edit: navigator.push(.editMemberAvatar(memberId: memberId, source: .stored))
        case .view: viewerURL = Self.avatarViewerURL(detail: AppState.shared.memberDetails[memberId])
        }
    }

    /// D4/D7: load the pick, make it upright and ≤ 2400px, then Edit photo. Dismissing the picker
    /// changes nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(.editMemberAvatar(memberId: memberId, source: .newPick(image)))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "MemberProfileContainer.openPicked", surface: true,
                                        friendlyMessage: Self.pickFailedMessage)
        }
    }

    @MainActor
    static func load(memberId: String, authManager: AuthManager) async {
        await AppState.shared.loadInitialData()                      // the org for the rail's scope
        let actions = MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MemberProfileContainer.signOut", surface: false)
            }
        })
        async let detail: () = actions.loadMember(memberId)
        async let groups: () = actions.loadMemberGroups(memberId)
        async let engagement: () = actions.loadEngagement(memberId)
        async let days: () = actions.loadMemberDays(memberId)
        _ = await (detail, groups, engagement, days)
    }

    /// Each URL already in Ui2ImageCache, else "" (C-059's missing-cover box until it lands).
    @MainActor
    static func cachedCoverURLs(_ urls: [String]) -> [String] {
        urls.map { raw in
            guard let url = URL(string: raw), Ui2ImageCache.shared.image(for: url) != nil else { return "" }
            return raw
        }
    }

    /// ui2-groups-browse D7: the page a group row opens — rows are `memberGroupsById` in order
    /// (MemberProfileMapper maps them one-for-one).
    static func groupDestination(_ groups: [MemberGroupItem]?, row: Int) -> UI2Destination? {
        guard let groups, groups.indices.contains(row) else { return nil }
        return .groupDetail(id: groups[row].id, name: groups[row].name)
    }

    // MARK: image-framing-editor D4/D13 — the avatar tap

    enum AvatarTap: Equatable { case none, picker, menu, googleMenu }

    enum AvatarChoice: String {
        case change = "Change image", edit = "Edit image", view = "View image"
        init?(label: String) { self.init(rawValue: label) }
    }

    /// D13: the viewer image's accessibility label.
    static let viewerLabel = "Profile photo"
    /// The banner an unreadable pick shows; the page stays.
    static let pickFailedMessage = "Couldn't open that photo"

    /// D4: read from AppState's member detail — inert until it has loaded. No avatar and no Google
    /// picture → the picker; Google-only → Change · View; an uploaded avatar → Change · Edit · View.
    static func avatarTap(detail: MemberDetail?) -> AvatarTap {
        guard let detail else { return .none }
        let picture = MembersHomeMapper.nonEmpty(detail.profilePicture)
        let google = MembersHomeMapper.nonEmpty(detail.googlePicture)
        if picture == nil && google == nil { return .picker }
        return isGoogleOnly(detail) ? .googleMenu : .menu
    }

    /// D4: the shown picture is Google's — no avatar (the Google picture shows), the avatar equals the
    /// Google picture, or it is served from googleusercontent.com. An R2 copy made at linking is not (D15).
    static func isGoogleOnly(_ detail: MemberDetail) -> Bool {
        guard let picture = MembersHomeMapper.nonEmpty(detail.profilePicture) else {
            return MembersHomeMapper.nonEmpty(detail.googlePicture) != nil
        }
        if picture == detail.googlePicture { return true }
        return URL(string: picture)?.host?.hasSuffix("googleusercontent.com") == true
    }

    /// D4: the C-066 rows — Edit · Change · View (Google-only: Change · View) — existing glyphs (an unknown name renders the red stub).
    static func avatarActions(_ tap: AvatarTap) -> [ActionMenuOverlay.ActionItem] {
        let change = ActionMenuOverlay.ActionItem(glyph: "upload", label: AvatarChoice.change.rawValue)
        let edit = ActionMenuOverlay.ActionItem(glyph: "edit", label: AvatarChoice.edit.rawValue)
        let view = ActionMenuOverlay.ActionItem(glyph: "eye", label: AvatarChoice.view.rawValue)
        switch tap {
        case .menu: return [edit, change, view]   // owner 2026-10-27: Edit first
        case .googleMenu: return [change, view]
        case .none, .picker: return []
        }
    }

    /// D13: the stored original when there is one, else the avatar, else the Google picture.
    static func avatarViewerURL(detail: MemberDetail?) -> String? {
        guard let detail else { return nil }
        return MembersHomeMapper.nonEmpty(detail.profilePictureOriginalUrl)
            ?? MembersHomeMapper.nonEmpty(detail.profilePicture)
            ?? MembersHomeMapper.nonEmpty(detail.googlePicture)
    }

    /// C-059 §4 `cover: Image?` is caller-resolved: the screen reads Ui2ImageCache only
    /// (`MembersProfileScreen.cachedImage`), so the page puts each program cover there. A cover
    /// that fails to load keeps C-059's missing-cover box. Returns whether any cover landed.
    @MainActor
    static func seedCovers(_ urls: [String]) async -> Bool {
        var seeded = false
        for raw in urls {
            guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: url) == nil else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    Ui2ImageCache.shared.seed(image, for: url)
                    seeded = true
                }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return seeded }
                AppState.shared.recordError(error, context: "MemberProfileContainer.seedCovers", surface: false)
            }
        }
        return seeded
    }
}
