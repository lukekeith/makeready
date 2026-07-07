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
    @State private var isApplying = false
    @State private var showApplyDialog = false

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
    }

    // MenuInput(.segmented) works on strings — map to/from EnrollmentSyncMode.
    private static let autoOption = "Automatic"
    private static let approvalOption = "Approval"

    private var syncIsOn: Bool {
        (status?.syncMode ?? .off) != .off
    }

    var body: some View {
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
                            driftSection(status)
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
        .overlay {
            DialogOverlay(
                isPresented: $showApplyDialog,
                title: "Apply updates?",
                message: "This brings the group's future lessons up to the latest published version. Lessons members already completed are never changed.",
                buttons: [
                    DialogButtonConfig("Apply updates", style: .primary) {
                        applyUpdates()
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ]
            )
        }
    }

    // MARK: - Drift / up-to-date sections

    @ViewBuilder
    private func driftSection(_ status: EnrollmentSyncStatus) -> some View {
        VStack(spacing: 8) {
            Text("UPDATES AVAILABLE")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(status.pendingVersions, id: \.versionNumber) { version in
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Version \(version.versionNumber)")
                            .font(Typography.s15Semibold)
                            .foregroundColor(.white)

                        Spacer()

                        Text(ModelFormatters.monthDay.string(from: version.publishedAt))
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    if let summary = version.changeSummary, !summary.isEmpty {
                        Text(summary)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }

            BoxButton(
                action: { showApplyDialog = true },
                label: isApplying ? "Applying..." : "Apply updates",
                variant: .primary,
                size: .lg,
                fullWidth: true
            )
            .opacity(isApplying ? 0.5 : 1.0)
            .disabled(isApplying)
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

    private func applyUpdates() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            do {
                try await EnrollmentActions().applySyncUpdates(enrollmentId: enrollmentId)
                await loadStatus()
                await MainActor.run { isApplying = false }
            } catch {
                await MainActor.run {
                    isApplying = false
                    state.recordError(
                        error,
                        context: "EnrollmentSyncPage.applyUpdates",
                        surface: true,
                        friendlyMessage: "Couldn't apply the updates",
                        retry: { applyUpdates() }
                    )
                }
            }
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
