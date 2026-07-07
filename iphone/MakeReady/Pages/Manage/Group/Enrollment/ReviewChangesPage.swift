//
//  ReviewChangesPage.swift
//  MakeReady
//
//  Review Changes — per-lesson approval of pending study-sync updates
//  (SlideStack detail of EnrollmentSyncPage). Grid rows: left column is the
//  lesson date with a colored new/updated/deleted tag; right column is the
//  quantified change summary and a per-lesson toggle. "Approve" in the
//  PageTitle applies the toggled-on lessons; rejected changes stay pending
//  and can be approved on a later visit.
//

import SwiftUI

struct ReviewChangesPage: View {
    let enrollmentId: String
    let onDismiss: () -> Void
    /// Called after a successful approval so the parent refreshes its status.
    let onApplied: () -> Void

    private var state: AppState { AppState.shared }

    @State private var pending: EnrollmentPendingChanges?
    @State private var isLoading: Bool
    @State private var error: String?
    @State private var isApproving = false

    /// Per-lesson approval toggles, keyed by change key. Default ON.
    @State private var approved: [String: Bool] = [:]

    /// Cold-open content gate (Class 3) — same contract as EnrollmentSyncPage.
    @State private var readyToShowContent: Bool

    init(enrollmentId: String, onDismiss: @escaping () -> Void, onApplied: @escaping () -> Void) {
        self.enrollmentId = enrollmentId
        self.onDismiss = onDismiss
        self.onApplied = onApplied

        let cached = AppState.shared.enrollmentPendingChangesById[enrollmentId]
        _pending = State(initialValue: cached)
        _isLoading = State(initialValue: cached == nil)
        _readyToShowContent = State(initialValue: cached != nil)
        if let cached {
            _approved = State(initialValue: Dictionary(
                uniqueKeysWithValues: cached.changes.map { ($0.key, true) }
            ))
        }
    }

    private var approvedKeys: [String] {
        (pending?.changes ?? []).map(\.key).filter { approved[$0] ?? true }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitleLink(
                title: "Review Changes",
                leftIcon: "chevron.left",
                // Hidden (empty) until there's something toggled on to approve.
                rightLink: approvedKeys.isEmpty ? "" : (isApproving ? "Approving..." : "Approve"),
                onLeftIconTap: { onDismiss() },
                onRightLinkTap: { approveSelected() }
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
                        Task { await load() }
                    }
                    .foregroundColor(Color.brandPrimary)
                }
                .padding(32)
                Spacer()
            } else if let pending = pending, pending.hasPending {
                SwipeableScrollView {
                    VStack(spacing: 8) {
                        ForEach(pending.changes) { change in
                            changeRow(change)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(Typography.s40)
                        .foregroundColor(.white.opacity(0.3))

                    Text("All caught up")
                        .font(Typography.s17Semibold)
                        .foregroundColor(.white)

                    Text("This enrollment has the latest version of the study")
                        .font(Typography.s15)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                Spacer()
            }
        }
        .background(Color.appBackground)
        .task {
            if !readyToShowContent {
                try? await Task.sleep(nanoseconds: 500_000_000)
                readyToShowContent = true
            }
        }
        .task { await load() }
    }

    // MARK: - Row (grid: date+tag | summary+toggle)

    @ViewBuilder
    private func changeRow(_ change: PendingLessonChange) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: date (or day number for not-yet-scheduled lessons)
            // with the colored change tag below.
            VStack(spacing: 6) {
                if let date = change.scheduledDate {
                    Text(ModelFormatters.monthAbbrev.string(from: date).uppercased())
                        .font(Typography.s13Bold)
                        .foregroundColor(Color.brandPrimary)
                    Text(ModelFormatters.dayOfMonth.string(from: date))
                        .font(Typography.s22Bold)
                        .foregroundColor(.white)
                } else {
                    Text("DAY")
                        .font(Typography.s13Bold)
                        .foregroundColor(Color.brandPrimary)
                    Text(change.dayNumber.map(String.init) ?? "–")
                        .font(Typography.s22Bold)
                        .foregroundColor(.white)
                }

                Text(tagLabel(change.type))
                    .font(Typography.s11Bold)
                    .foregroundColor(Color.appBackground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tagColor(change.type))
                    .clipShape(Capsule())
            }
            .frame(width: 64)

            // Right column: what changed for this lesson.
            VStack(alignment: .leading, spacing: 4) {
                if let title = change.title, !title.isEmpty {
                    Text(title)
                        .font(Typography.s15Semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Text(changeSummary(change))
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Lesson-level approval toggle (design-system pill).
            CustomToggle(isOn: Binding(
                get: { approved[change.key] ?? true },
                set: { approved[change.key] = $0 }
            ))
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private func tagLabel(_ type: PendingLessonChange.ChangeType) -> String {
        switch type {
        case .new: return "NEW"
        case .updated: return "UPDATED"
        case .removed: return "DELETED"
        }
    }

    private func tagColor(_ type: PendingLessonChange.ChangeType) -> Color {
        switch type {
        case .new: return Color.success
        case .updated: return Color.warning
        case .removed: return Color.destructive
        }
    }

    /// Quantified per-lesson summary: activity counts + title changes.
    private func changeSummary(_ change: PendingLessonChange) -> String {
        switch change.type {
        case .removed:
            let count = change.activities?.removed ?? 0
            return count > 0
                ? "Lesson removed (\(count) \(count == 1 ? "activity" : "activities"))"
                : "Lesson removed"
        case .new:
            let count = change.activities?.added ?? 0
            return count > 0
                ? "New lesson with \(count) \(count == 1 ? "activity" : "activities")"
                : "New lesson"
        case .updated:
            var parts: [String] = []
            if let a = change.activities {
                if a.updated > 0 { parts.append("\(a.updated) updated") }
                if a.added > 0 { parts.append("\(a.added) added") }
                if a.removed > 0 { parts.append("\(a.removed) removed") }
            }
            var line = parts.isEmpty ? "" : "Activities: \(parts.joined(separator: " · "))"
            if change.titleChanged {
                line = line.isEmpty ? "Title changed" : "\(line)\nTitle changed"
            }
            return line.isEmpty ? "Content updated" : line
        }
    }

    // MARK: - Data

    private func load() async {
        if pending == nil { isLoading = true }
        error = nil
        do {
            let loaded = try await EnrollmentActions().getPendingChanges(enrollmentId: enrollmentId)
            pending = loaded
            // Default every (new) row to approved; keep existing choices.
            for change in loaded.changes where approved[change.key] == nil {
                approved[change.key] = true
            }
            isLoading = false
        } catch {
            // Console-only: load failure surfaces as the full-screen error
            // state with Try Again, never the banner.
            state.recordError(error, context: "ReviewChangesPage.load")
            if pending == nil {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func approveSelected() {
        guard !isApproving else { return }
        let keys = approvedKeys
        guard !keys.isEmpty else { return }
        isApproving = true

        Task {
            do {
                try await EnrollmentActions().applySyncUpdates(enrollmentId: enrollmentId, lessonKeys: keys)
                // Silent: approval resolved/kept the notification server-side —
                // refresh the banner/feed count either way.
                try? await NotificationActions().loadNotifications()
                try? await NotificationActions().loadUnreadCount()
                await MainActor.run {
                    isApproving = false
                    onApplied()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    // Cleanup first, then record — the user just tapped Approve.
                    // Safe to re-run: apply is idempotent per lesson.
                    isApproving = false
                    state.recordError(
                        error,
                        context: "ReviewChangesPage.approveSelected",
                        surface: true,
                        friendlyMessage: "Couldn't apply the updates",
                        retry: { approveSelected() }
                    )
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        ReviewChangesPage(
            enrollmentId: "preview",
            onDismiss: {},
            onApplied: {}
        )
    }
}
