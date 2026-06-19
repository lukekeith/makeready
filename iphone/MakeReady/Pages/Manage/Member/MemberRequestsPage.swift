//
//  MemberRequestsPage.swift
//  MakeReady
//
//  Displays pending join requests - navigated from Members tab card
//

import SwiftUI

struct MemberRequestsPage: View {
    let overlayManager: OverlayManager
    let onRequestApproved: () -> Void

    private var state: AppState { AppState.shared }
    @Environment(\.pageDismiss) private var pageDismiss

    /// Derived from AppState so approving/rejecting (which mutate
    /// `pendingJoinRequestsByGroupId`) removes the card reactively — no stale
    /// snapshot. Ordered by the group order for stability.
    private var allJoinRequests: [GroupJoinRequest] {
        state.orderedGroups.flatMap { group in
            (state.pendingJoinRequestsByGroupId[group.id] ?? []).map {
                GroupJoinRequest(groupId: group.id, request: $0)
            }
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitle(
                    title: "Member Requests",
                    icon: "chevron.left",
                    onIconTap: {
                        if let pageDismiss { pageDismiss() }
                        else { overlayManager.dismiss(.memberRequests) }
                    }
                )

                if allJoinRequests.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.clock")
                                .font(Typography.s48)
                                .foregroundColor(.white.opacity(0.3))
                            Text("No pending requests")
                                .font(Typography.s17Semibold)
                                .foregroundColor(.white.opacity(0.2))
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(allJoinRequests, id: \.id) { groupRequest in
                                requestRow(groupRequest)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        // Animate the diff: an approved/rejected card shrinks +
                        // fades out as it leaves the list.
                        .animation(Motion.standard, value: allJoinRequests.map(\.id))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
    }

    private func requestRow(_ groupRequest: GroupJoinRequest) -> some View {
        CardMember(
            data: CardMemberData(
                id: groupRequest.id,
                firstName: groupRequest.request.member.firstName ?? "",
                lastName: groupRequest.request.member.lastName ?? "",
                avatarURL: groupRequest.request.member.avatarUrl,
                metadata: requestMetadata(groupRequest),
                groups: [],
                onTap: {
                    handleRequestTap(groupRequest)
                }
            )
        ) {
            ActionButton(label: "Respond", variant: .purple) {
                handleRespond(groupRequest)
            }
        }
    }

    private func handleRespond(_ groupRequest: GroupJoinRequest) {
        let name = [groupRequest.request.member.firstName, groupRequest.request.member.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let displayName = name.isEmpty ? "This member" : name
        let groupName = state.groups[groupRequest.groupId]?.name ?? "the group"

        overlayManager.present(.memberRequestRespond) {
            MemberRequestRespondModal(
                memberName: displayName,
                groupName: groupName,
                requestDate: groupRequest.request.createdAt,
                onApprove: {
                    overlayManager.dismiss(.memberRequestRespond)
                    Task { await approveRequest(groupRequest) }
                },
                onReject: {
                    overlayManager.dismiss(.memberRequestRespond)
                    Task { await rejectRequest(groupRequest) }
                },
                onCancel: {
                    overlayManager.dismiss(.memberRequestRespond)
                }
            )
        }
    }

    private func handleRequestTap(_ groupRequest: GroupJoinRequest) {
        let groupName = state.groups[groupRequest.groupId]?.name ?? "Unknown"
        overlayManager.present(.memberRequestProfile) {
            MemberRequestProfilePage(
                memberId: groupRequest.request.member.id,
                groupId: groupRequest.groupId,
                groupName: groupName,
                requestId: groupRequest.request.id,
                requestDate: groupRequest.request.createdAt,
                requestMessage: groupRequest.request.message,
                onApprove: {
                    onRequestApproved()
                }
            )
        }
    }

    private func requestMetadata(_ groupRequest: GroupJoinRequest) -> [DataItem] {
        var items: [DataItem] = []

        if let groupName = state.groups[groupRequest.groupId]?.name {
            items.append(DataItem(label: "Group", value: groupName))
        }

        items.append(DataItem(label: "Requested", value: DateFormatters.monthDayYear.string(from: groupRequest.request.createdAt)))

        return items
    }

    private func approveRequest(_ groupRequest: GroupJoinRequest) async {
        do {
            // Synchronous AppState removal inside the action so the red-dot
            // indicators on group cards / group-home update instantly.
            try await GroupActions().approveJoinRequest(
                groupId: groupRequest.groupId,
                requestId: groupRequest.request.id
            )
            onRequestApproved()
        } catch {
            // User tapped Approve — surface; approval by id is safe to re-run.
            state.recordError(
                error,
                context: "MemberRequestsPage.approveRequest",
                surface: true,
                friendlyMessage: "Couldn't approve the request",
                retry: { Task { await approveRequest(groupRequest) } }
            )
        }
    }

    private func rejectRequest(_ groupRequest: GroupJoinRequest) async {
        do {
            try await GroupActions().rejectJoinRequest(
                groupId: groupRequest.groupId,
                requestId: groupRequest.request.id
            )
            // Reuse the same refresh callback as approval — the request is
            // resolved and removed from the pending list either way.
            onRequestApproved()
        } catch {
            // User tapped Reject — surface; rejection by id is safe to re-run.
            state.recordError(
                error,
                context: "MemberRequestsPage.rejectRequest",
                surface: true,
                friendlyMessage: "Couldn't reject the request",
                retry: { Task { await rejectRequest(groupRequest) } }
            )
        }
    }
}
