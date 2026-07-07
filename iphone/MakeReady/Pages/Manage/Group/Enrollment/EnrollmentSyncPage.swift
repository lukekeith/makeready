//
//  EnrollmentSyncPage.swift
//  MakeReady
//
//  Study Sync settings for one enrollment (study-sync phase 6).
//  Sync toggle (OFF ↔ AUTO/APPROVAL), mode chooser, pending published
//  versions with their AI change summaries, and "Apply updates".
//
//  Reached two ways:
//    • EnrollmentSchedulePage → sync icon (SlideStack detail, chevron back)
//    • Notification action `view: enrollment-sync` (overlay modal, xmark)
//

import SwiftUI

struct EnrollmentSyncPage: View {
    let enrollmentId: String
    let onDismiss: () -> Void
    var leftIcon: String = "chevron.left"  // "xmark" when presented as modal
    var programName: String? = nil         // context line under the title

    private var state: AppState { AppState.shared }

    @State private var status: EnrollmentSyncStatus?
    @State private var isLoading: Bool
    @State private var error: String?

    /// Quantified pending-change counts for the summary card (loaded with
    /// status; the Review Changes pane loads the per-lesson rows itself).
    @State private var pendingCounts: EnrollmentPendingChanges.Counts?

    /// SlideStack detail: the Review Changes screen.
    @State private var showReviewChanges = false

    /// Gates the spinner→content swap on a COLD open: a response landing
    /// mid-slide is a structural change outside the animation transaction and
    /// pops to its final position (Class 3). The spinner renders from frame 1
    /// and rides the slide; content swaps in once the animation has settled.
    /// A warm cache skips the gate — content itself rides from frame 1.
    @State private var readyToShowContent: Bool

    // Cache-first (SWIFTUI_TRANSITIONS.md § Pre-loading Content): render the
    // cached status synchronously so content rides the slide/modal animation;
    // the .task refresh replaces it silently. EnrollmentSchedulePage warms
    // this cache when it loads, so the sync icon's first tap is usually warm.
    init(
        enrollmentId: String,
        onDismiss: @escaping () -> Void,
        leftIcon: String = "chevron.left",
        programName: String? = nil
    ) {
        self.enrollmentId = enrollmentId
        self.onDismiss = onDismiss
        self.leftIcon = leftIcon
        self.programName = programName

        let cached = AppState.shared.enrollmentSyncStatusById[enrollmentId]
        _status = State(initialValue: cached)
        _isLoading = State(initialValue: cached == nil)
        _readyToShowContent = State(initialValue: cached != nil)
        _pendingCounts = State(
            initialValue: AppState.shared.enrollmentPendingChangesById[enrollmentId]?.counts
        )
    }

    // MenuInput(.segmented) works on strings — map to/from EnrollmentSyncMode.
    private static let autoOption = "Automatic"
    private static let approvalOption = "Approval"

    private var syncIsOn: Bool {
        (status?.syncMode ?? .off) != .off
    }

    var body: some View {
        SlideStack(isPresented: $showReviewChanges) {
            syncContent
        } detail: {
            ReviewChangesPage(
                enrollmentId: enrollmentId,
                onDismiss: { showReviewChanges = false },
                onApplied: {
                    Task {
                        await loadStatus()
                        await loadPendingCounts()
                    }
                }
            )
            .environment(\.isModalRoot, false)
        }
        .background(Color.appBackground)
        .task {
            // Cold open: hold the structure stable until the slide/modal
            // settles (SlideStack is 0.3s, modal appear 0.4s) so the loaded
            // content doesn't swap in mid-animation and pop (Class 3).
            if !readyToShowContent {
                try? await Task.sleep(nanoseconds: 500_000_000)
                readyToShowContent = true
            }
        }
        .task { await loadStatus() }
        .task { await loadPendingCounts() }
    }

    private var syncContent: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Study Sync",
                icon: leftIcon,
                onIconTap: { onDismiss() }
            )

            if isLoading || !readyToShowContent {
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.5))
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(Typography.s40)
                        .foregroundColor(.white.opacity(0.3))

                    Text(error)
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task { await loadStatus() }
                    }
                    .foregroundColor(Color.brandPrimary)
                }
                .padding(32)
                Spacer()
            } else if let status = status {
                ScrollView {
                    VStack(spacing: 20) {
                        if let programName {
                            Text(programName)
                                .font(Typography.s13Semibold)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ToggleGroup {
                            ToggleControl(
                                title: "Sync to study",
                                description: "Keep this group's lessons up to date when the study publishes changes. Completed lessons are never changed.",
                                isOn: Binding(
                                    get: { syncIsOn },
                                    set: { on in setMode(on ? .auto : .off) }
                                )
                            )
                        }

                        if syncIsOn {
                            VStack(spacing: 8) {
                                MenuInput(
                                    label: "Updates",
                                    options: [Self.autoOption, Self.approvalOption],
                                    selectedOption: Binding(
                                        get: {
                                            status.syncMode == .approval
                                                ? Self.approvalOption
                                                : Self.autoOption
                                        },
                                        set: { option in
                                            setMode(option == Self.approvalOption ? .approval : .auto)
                                        }
                                    ),
                                    style: .segmented
                                )

                                Text(
                                    status.syncMode == .approval
                                        ? "You review updates and choose when to apply them."
                                        : "Published updates apply to future lessons right away."
                                )
                                .font(Typography.s13)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if status.hasDrift {
                            driftSummaryCard
                        } else {
                            upToDateRow(status)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Drift / up-to-date sections

    /// Quantified summary card — counts only, tap to Review Changes.
    private var driftSummaryCard: some View {
        VStack(spacing: 8) {
            Text("UPDATES AVAILABLE")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showReviewChanges = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let counts = pendingCounts {
                            countRow(label: "Lessons", updated: counts.lessonsUpdated,
                                     added: counts.lessonsNew, removed: counts.lessonsRemoved)
                            countRow(label: "Activities", updated: counts.activitiesUpdated,
                                     added: counts.activitiesNew, removed: counts.activitiesRemoved)
                        } else {
                            Text("Review pending changes")
                                .font(Typography.s15Semibold)
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    /// One matrix row: "Lessons   2 updated · 1 new · 1 removed".
    @ViewBuilder
    private func countRow(label: String, updated: Int, added: Int, removed: Int) -> some View {
        let parts = [
            updated > 0 ? "\(updated) updated" : nil,
            added > 0 ? "\(added) new" : nil,
            removed > 0 ? "\(removed) removed" : nil,
        ].compactMap { $0 }

        if !parts.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 72, alignment: .leading)

                Text(parts.joined(separator: " · "))
                    .font(Typography.s15)
                    .foregroundColor(.white)
            }
        }
    }

    private func upToDateRow(_ status: EnrollmentSyncStatus) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.5))

            Text(
                status.currentVersionNumber.map { "Up to date — version \($0)" }
                    ?? "Up to date"
            )
            .font(Typography.s15)
            .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Data

    private func loadStatus() async {
        if status == nil { isLoading = true }
        error = nil
        do {
            let loaded = try await EnrollmentActions().getSyncStatus(enrollmentId: enrollmentId)
            status = loaded
            isLoading = false
        } catch {
            // Console-only: load failure surfaces as the full-screen error
            // state with Try Again, never the banner.
            state.recordError(error, context: "EnrollmentSyncPage.loadStatus")
            if status == nil {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Optimistic mode change: flip locally, PATCH, revert on failure.
    private func setMode(_ mode: EnrollmentSyncMode) {
        guard let current = status, current.syncMode != mode else { return }
        status = EnrollmentSyncStatus(
            syncMode: mode,
            syncedProgramVersionNumber: current.syncedProgramVersionNumber,
            currentVersionNumber: current.currentVersionNumber,
            hasDrift: current.hasDrift,
            pendingVersions: current.pendingVersions
        )
        Task {
            do {
                try await EnrollmentActions().updateSyncMode(enrollmentId: enrollmentId, mode: mode)
                await MainActor.run {
                    // Keep the cache-first snapshot in step with the saved mode.
                    if let saved = status {
                        state.enrollmentSyncStatusById[enrollmentId] = saved
                    }
                }
                // Silent: the mode change resolved the "updates available"
                // notification server-side — refresh the banner/feed count.
                try? await NotificationActions().loadNotifications()
                try? await NotificationActions().loadUnreadCount()
            } catch {
                await MainActor.run {
                    status = current
                    state.recordError(
                        error,
                        context: "EnrollmentSyncPage.setMode",
                        surface: true,
                        friendlyMessage: "Couldn't update sync settings",
                        retry: { setMode(mode) }
                    )
                }
            }
        }
    }

    /// Counts for the summary card (and warms the Review pane's cache).
    private func loadPendingCounts() async {
        guard status?.hasDrift != false else { return }
        do {
            let pending = try await EnrollmentActions().getPendingChanges(enrollmentId: enrollmentId)
            pendingCounts = pending.counts
        } catch {
            // Console-only: the card falls back to "Review pending changes".
            state.recordError(error, context: "EnrollmentSyncPage.loadPendingCounts")
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        EnrollmentSyncPage(
            enrollmentId: "preview",
            onDismiss: {},
            programName: "Daily Inspiration"
        )
    }
}
