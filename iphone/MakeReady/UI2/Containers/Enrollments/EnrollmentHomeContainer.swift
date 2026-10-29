import SwiftUI

/// ui2-enrollments-browse §iphone: the pushed `.enrollmentHome` page (D20). It owns its ScrollView
/// and pins C-040 above it (`showsHeader: false`, the StudyProgramHomeContainer precedent). The store
/// renders at once under the pushed name; every visit reloads. "Edit schedule" and the calendar glyph
/// are hidden (`showsScheduleEditing: false`, P10); day-card, lesson and slide taps are inert.
struct EnrollmentHomeContainer: View {
    let enrollmentId: String
    let name: String

    static let pageTitle = "Enrollment"

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var loading = false
    @State private var failed = false
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var imagesSeeded = 0

    var body: some View {
        let mapped = EnrollmentHomeMapper.state(
            .init(name: name, home: AppState.shared.enrollmentHomes[enrollmentId], loading: loading, failed: failed),
            today: Date(), timeZone: .current)
        let _ = imagesSeeded
        let state = Self.cachedImages(mapped)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: Self.pageTitle,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            ScrollView(.vertical) {
                EnrollmentHomeScreen(
                    state: state,
                    showsScheduleEditing: false,
                    showsHeader: false,
                    onBack: { navigator.pop() },
                    onRetry: { Task { await reload() } }
                )
            }
            .scrollIndicators(.hidden)
            .pullDownRefresh { await reload() }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await reload() }
        .task(id: Self.imageURLs(mapped)) {
            if await UI2ImageLoader.seed(Self.imageURLs(mapped), context: "EnrollmentHomeContainer") { imagesSeeded += 1 }
        }
    }

    @MainActor
    private func reload() async {
        loading = true
        defer { loading = false }
        failed = !(await Self.load(id: enrollmentId, actions: EnrollmentActions(), state: .shared, onUnauthorized: signOut))
    }

    /// true = loaded. Cancelled → nothing; 401 → sign-out; anything else (a 404 included) keeps what
    /// is shown, console-only — the page's retry is pull-down.
    @MainActor
    static func load(id: String, actions: EnrollmentActions, state: AppState,
                     onUnauthorized: @MainActor () async -> Void) async -> Bool {
        do {
            try await actions.loadHome(id: id, forceRefresh: true)
            return true
        } catch {
            if GroupActions.isCancellation(error) { return true }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            state.recordError(error, context: "EnrollmentHomeContainer.loadHome")
            return false
        }
    }

    static func imageURLs(_ s: EnrollmentHomeScreen.State) -> [String] {
        ([s.coverURL] + s.lessonSlideImages.flatMap { $0 }).filter { !$0.isEmpty }
    }

    @MainActor
    static func cachedImages(_ mapped: EnrollmentHomeScreen.State) -> EnrollmentHomeScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        return s
    }

    private var signOut: @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EnrollmentHomeContainer.signOut", surface: false)
            }
        }
    }
}
