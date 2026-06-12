//
//  OrgHomePage.swift
//  MakeReady
//
//  Top-level page for an organization the user belongs to. Two tabs:
//  - Details: name, owner, created date, member count
//  - Group Leaders: list of group leaders in the org
//
//  Presented from UserMenu via overlayManager.present(.orgHome).
//

import SwiftUI

struct OrgHomePage: View {
    let overlayManager: OverlayManager
    let organization: OrganizationData
    var onDismiss: (() -> Void)?
    var leftIcon: String = "xmark"

    @Environment(AuthManager.self) var authManager

    @State private var selectedTab: Int = 0
    @State private var groupLeaders: [GroupLeader] = []
    @State private var isLoadingLeaders: Bool = true
    @State private var leadersError: String?
    @State private var memberCount: Int?

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitle(
                    title: organization.name,
                    icon: leftIcon,
                    onIconTap: dismiss
                )

                TabSlider(
                    tabs: ["Details", "Group Leaders"],
                    selectedIndex: $selectedTab
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Group {
                    switch selectedTab {
                    case 0:
                        detailsTab
                    case 1:
                        groupLeadersTab
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 16)
            }
        }
        .task {
            async let leadersLoad: () = loadLeaders()
            async let countLoad: () = loadMemberCount()
            _ = await (leadersLoad, countLoad)
        }
    }

    // MARK: - Tabs

    private var detailsTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                detailRow(label: "Name", value: organization.name)

                if let ownerId = organization.ownerId {
                    let isMe = ownerId == authManager.currentUser?.id
                    detailRow(label: "Owner", value: isMe ? "You" : ownerId)
                }

                if let createdAt = organization.createdAt {
                    detailRow(label: "Created", value: Self.dateFormatter.string(from: createdAt))
                }

                if let memberCount {
                    detailRow(label: "Members", value: "\(memberCount)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var groupLeadersTab: some View {
        if isLoadingLeaders {
            VStack {
                Spacer().frame(height: 60)
                ProgressView()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = leadersError {
            VStack {
                Spacer().frame(height: 60)
                Text(error)
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groupLeaders.isEmpty {
            VStack {
                Spacer().frame(height: 60)
                Text("No group leaders in this organization yet.")
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupLeaders) { leader in
                        leaderRow(leader: leader)
                        if leader.id != groupLeaders.last?.id {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Rows

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typography.s14Medium)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(Typography.s14Medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    private func leaderRow(leader: GroupLeader) -> some View {
        HStack(spacing: 12) {
            Avatar(
                imageURL: leader.avatarUrl,
                firstName: leader.firstName,
                lastName: leader.lastName,
                size: .md
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(leader.displayName)
                    .font(Typography.s16Medium)
                    .foregroundColor(.white)
                Text(leaderSubtitle(leader: leader))
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func leaderSubtitle(leader: GroupLeader) -> String {
        let programs = "\(leader.programCount) program\(leader.programCount == 1 ? "" : "s")"
        let media = "\(leader.mediaCount) media"
        return "\(programs) · \(media)"
    }

    // MARK: - Load

    private func loadLeaders() async {
        do {
            let leaders = try await ProgramActions().loadGroupLeaders()
            groupLeaders = leaders
            leadersError = nil
        } catch {
            // Background load — the in-page error state shows it; record
            // console-only for the error history.
            leadersError = "Failed to load group leaders."
            AppState.shared.recordError(error, context: "OrgHomePage.loadLeaders")
        }
        isLoadingLeaders = false
    }

    private func loadMemberCount() async {
        do {
            memberCount = try await OrgActions().loadMemberCount(organizationId: organization.id)
        } catch {
            // Best-effort; leave nil so the row simply doesn't render.
            // Background load — console-only.
            AppState.shared.recordError(error, context: "OrgHomePage.loadMemberCount")
        }
    }

    // MARK: - Helpers

    private func dismiss() {
        overlayManager.dismiss(.orgHome)
        onDismiss?()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
