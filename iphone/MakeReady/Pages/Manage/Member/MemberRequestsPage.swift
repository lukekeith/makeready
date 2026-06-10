//
//  MemberRequestsPage.swift
//  MakeReady
//
//  Displays pending join requests - navigated from Members tab card
//

import SwiftUI

struct MemberRequestsPage: View {
    let overlayManager: OverlayManager
    let allJoinRequests: [GroupJoinRequest]
    let onRequestApproved: () -> Void

    private var state: AppState { AppState.shared }
    @Environment(\.pageDismiss) private var pageDismiss

    @State private var showAcceptConfirmation: Bool = false
    @State private var requestToAccept: GroupJoinRequest?

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
                        else { overlayManager.dismiss(id: OverlayID.memberRequests) }
                    }
                )

                if allJoinRequests.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No pending requests")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(allJoinRequests, id: \.id) { groupRequest in
                                requestRow(groupRequest)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .alert("Accept Request", isPresented: $showAcceptConfirmation) {
            Button("Cancel", role: .cancel) {
                requestToAccept = nil
            }
            Button("Accept") {
                if let groupRequest = requestToAccept {
                    Task {
                        await approveRequest(groupRequest)
                    }
                }
                requestToAccept = nil
            }
        } message: {
            if let groupRequest = requestToAccept {
                let name = [groupRequest.request.member.firstName, groupRequest.request.member.lastName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let groupName = state.groups[groupRequest.groupId]?.name ?? "the group"
                Text("Accept \(name) as a member of \(groupName)?")
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
            ActionButton(label: "Accept", variant: .purple) {
                requestToAccept = groupRequest
                showAcceptConfirmation = true
            }
        }
    }

    private func handleRequestTap(_ groupRequest: GroupJoinRequest) {
        let groupName = state.groups[groupRequest.groupId]?.name ?? "Unknown"
        overlayManager.presentModal(id: OverlayID.memberRequestProfile) {
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
            NSLog("Failed to approve request: \(error.localizedDescription)")
        }
    }
}
