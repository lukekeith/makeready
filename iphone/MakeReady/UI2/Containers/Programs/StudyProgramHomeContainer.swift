import PhotosUI
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
    /// D11 (group-cover-image D1–D3): the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D11: the cover menu, and the row chosen in it — acted on once the menu has slid out.
    @State private var coverMenuOpen = false
    @State private var pendingCoverChoice: GroupDetailContainer.CoverChoice?
    /// D11: the viewer's URL while it is up.
    @State private var viewerURL: String?
    /// image-viewer-zoom-dismiss: the cover's on-screen frame — the viewer grows from it and flies
    /// back into it.
    @State private var coverFrame: CGRect?

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
                        // D11: no cover → the picker; a cover → Edit · Change · View.
                        onCoverTap: { handleCoverTap() },
                        onRetry: { Task { await reload() } },
                        onCoverFrameChange: { coverFrame = $0 }
                    )
                }
                .scrollIndicators(.hidden)
                .pullDownRefresh { await reload() }
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        // D11 (group-cover-image D2): the chosen row runs after the menu has finished hiding — the
        // overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: coverMenuOpen, onDismiss: { coverMenuOpen = false },
                                onHidden: { runPendingCoverChoice() }) {
            ActionMenuOverlay(
                actions: GroupDetailContainer.coverActions,
                onSelect: { item in
                    pendingCoverChoice = GroupDetailContainer.CoverChoice(label: item.label)
                    coverMenuOpen = false
                },
                onDone: { coverMenuOpen = false }
            )
        }
        // The system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        .coverViewerPresentation(url: viewerURL, sourceFrame: coverFrame, accessibilityLabel: "Program cover", onClose: { viewerURL = nil })
        .task { await reload() }
        .task(id: Self.imageURLs(mapped)) {
            if await UI2ImageLoader.seed(Self.imageURLs(mapped), context: "StudyProgramHomeContainer") { imagesSeeded += 1 }
        }
        .task(id: mapped.enrollmentPhotoURLs) {
            if await CoverImageLoader.seedList(mapped.enrollmentPhotoURLs) { imagesSeeded += 1 }
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

    // MARK: - Cover (D11)

    private var coverOwner: CoverOwner { .program(programId) }

    private func handleCoverTap() {
        switch CoverOwner.coverTap(coverOwner.fields) {
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
        case .edit: navigator.push(coverOwner.destination(.stored))
        case .view: viewerURL = coverOwner.fields.flatMap(CoverOwner.viewerURL)
        }
    }

    /// Load the pick, make it upright and ≤ 2400px, then Edit cover. Dismissing the picker changes
    /// nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(coverOwner.destination(.newPick(image)))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.openPicked", surface: true,
                                        friendlyMessage: "Couldn't open that photo")
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

    /// D6: the full-size images the container seeds — the cover (≤1200px) and the lesson slides.
    /// The enrollment rows' group covers are list copies (cover-image-sizes, CoverImageLoader).
    static func imageURLs(_ state: StudyProgramHomeScreen.State) -> [String] {
        ([state.coverURL] + state.lessonSlideImages.flatMap { $0 }).filter { !$0.isEmpty }
    }

    /// Each image URL already in Ui2ImageCache, else "" (the component's empty look until it lands).
    @MainActor
    static func cachedImages(_ mapped: StudyProgramHomeScreen.State) -> StudyProgramHomeScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        s.enrollmentPhotoURLs = CoverImageLoader.cachedListURLs(mapped.enrollmentPhotoURLs)
        return s
    }
}
