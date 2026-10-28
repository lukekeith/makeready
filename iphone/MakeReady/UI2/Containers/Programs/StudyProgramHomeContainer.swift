import SwiftUI

/// ui2-programs §iphone Program page: the pushed `.studyProgramHome` page (D5–D7). It owns its
/// ScrollView and pins C-040 above it (`showsHeader: false`, the GroupDetailContainer precedent);
/// the ScrollView's pull-down reloads — the page's only retry (owner 2026-10-28). Cache-first: the
/// stores render at once under the pushed name while the program (every lesson page) and its
/// enrollments load in parallel.
struct StudyProgramHomeContainer: View {
    let programId: String
    let name: String

    /// D5: the banner when the program turns out to be gone.
    static let goneMessage = "This program is no longer available"
    /// D9: the banner when adding a lesson fails.
    static let addLessonFailedMessage = "Couldn't add a lesson"
    /// D5: how long the push takes to settle before a 404 pops it.
    static let pushSettle: Duration = .milliseconds(400)

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe (D6).
    @State private var imagesSeeded = 0
    /// D5: the program load failed this visit (with nothing cached, the page says pull to refresh).
    @State private var failed = false
    /// D7: the selected DayChip.
    @State private var activeDay = 1
    /// D9: one add in flight.
    @State private var addingLesson = false

    var body: some View {
        let app = AppState.shared
        let mapped = StudyProgramHomeMapper.state(
            .init(name: name, program: app.programs[programId], lessons: app.lessonsFor(programId: programId),
                  enrollments: app.programEnrollmentsFor(programId: programId), failed: failed, activeDay: activeDay),
            timeZone: .current
        )
        let _ = imagesSeeded
        let state = Self.cachedImages(mapped)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: "Study program",
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    StudyProgramHomeScreen(
                        state: state,
                        showsHeader: false,
                        onBack: { navigator.pop() },
                        // D10: a settings row → that field's edit page ("Lessons" maps to nothing, D7).
                        onEditField: { label in
                            guard let next = Self.editDestination(programId: programId, label: label,
                                                                  program: AppState.shared.programs[programId]) else { return }
                            navigator.push(next)
                        },
                        onAddLesson: { Task { await addLesson() } },
                        // D7/OQ-11: select the chip and bring that day's card into view.
                        onSelectDay: { day in
                            activeDay = day
                            withAnimation { proxy.scrollTo(StudyProgramHomeScreen.lessonScrollID(day), anchor: .top) }
                        },
                        onCoverTap: {},          // D11: the cover flow lands in Task 15
                        onRetry: { Task { await reload() } }
                    )
                }
                .scrollIndicators(.hidden)
                .pullToRefresh { await reload() }
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await reload() }
        .task(id: Self.imageURLs(mapped)) {
            if await MemberProfileContainer.seedCovers(Self.imageURLs(mapped)) { imagesSeeded += 1 }
        }
    }

    // MARK: - Load (D5)

    /// What a failed program load means for the page.
    enum LoadFailure: Equatable { case cancelled, signOut, gone, failed }

    static func loadFailure(for error: Error) -> LoadFailure {
        if GroupActions.isCancellation(error) { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) { return .signOut }
        if let http = error as? APIHTTPError, http.status == 404 { return .gone }
        return .failed
    }

    /// D5: the program (every lesson page) and its enrollments, at once.
    @MainActor
    private func reload() async {
        async let enrollments: () = loadEnrollments()
        do {
            try await ProgramActions().loadProgram(id: programId)
            failed = false
        } catch {
            await handleProgramFailure(error)
        }
        _ = await enrollments
    }

    @MainActor
    private func handleProgramFailure(_ error: Error) async {
        switch Self.loadFailure(for: error) {
        case .cancelled:
            return
        case .signOut:
            await signOut()
        case .gone:
            // D5: forget it and go back to the list once the push has settled.
            ProgramActions().forgetProgram(id: programId)
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadProgram", surface: true,
                                        friendlyMessage: Self.goneMessage)
            try? await Task.sleep(for: Self.pushSettle)
            navigator.popTo(0)
        case .failed:
            failed = true
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadProgram", surface: false)
        }
    }

    /// D5/D16: a failure keeps the rest of the page and is recorded, console-only.
    @MainActor
    private func loadEnrollments() async {
        do {
            _ = try await ProgramActions().getProgramEnrollments(programId: programId, forceRefresh: true)
        } catch {
            switch Self.loadFailure(for: error) {
            case .cancelled: return
            case .signOut: await signOut()
            case .gone, .failed:
                AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadEnrollments", surface: false)
            }
        }
    }

    // MARK: - Lessons + (D9)

    @MainActor
    private func addLesson() async {
        guard !addingLesson, AppState.shared.programs[programId] != nil else { return }
        addingLesson = true
        defer { addingLesson = false }
        do {
            _ = try await ProgramActions().addLesson(programId: programId)
            await reload()
        } catch {
            switch Self.loadFailure(for: error) {
            case .cancelled: return
            case .signOut: await signOut()
            case .gone, .failed:
                AppState.shared.recordError(error, context: "StudyProgramHomeContainer.addLesson", surface: true,
                                            friendlyMessage: Self.addLessonFailedMessage,
                                            retry: { Task { await addLesson() } })
            }
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    @MainActor
    private func signOut() async {
        do { try await authManager.signOut() } catch {
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.signOut", surface: false)
        }
    }

    // MARK: - Pure helpers

    /// D10: the row label's edit page — nil for "Lessons"/unknown labels, or while the program has
    /// not loaded (nothing to edit yet).
    static func editDestination(programId: String, label: String, program: StudyProgram?) -> UI2Destination? {
        guard program != nil, let field = ProgramField(label: label) else { return nil }
        return .editProgramField(programId: programId, field: field)
    }

    /// D6: the images the container seeds — the cover, the lesson slides, the enrollment photos.
    static func imageURLs(_ state: StudyProgramHomeScreen.State) -> [String] {
        ([state.coverURL] + state.lessonSlideImages.flatMap { $0 } + state.enrollmentPhotoURLs).filter { !$0.isEmpty }
    }

    /// Each image URL already in Ui2ImageCache, else "" (the component's empty look until it lands).
    @MainActor
    static func cachedImages(_ mapped: StudyProgramHomeScreen.State) -> StudyProgramHomeScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        s.enrollmentPhotoURLs = MemberProfileContainer.cachedCoverURLs(mapped.enrollmentPhotoURLs)
        return s
    }
}
