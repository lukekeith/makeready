//
//  MainGroups.swift
//  MakeReady
//
//  Groups tab page content - wraps MemberHomePage
//

import SwiftUI

struct MainGroups: View {
    let overlayManager: OverlayManager
    let avatarURL: String?
    @Binding var pendingSubTab: Int?

    var body: some View {
        MemberHomePage(
            overlayManager: overlayManager,
            avatarURL: avatarURL,
            pendingSubTab: $pendingSubTab
        )
    }
}

#Preview("Groups Tab") {
    MainGroupsPreviewGroupsTab()
}

#Preview("Members Tab") {
    MainGroupsPreviewMembersTab()
}

#Preview("Requests Tab") {
    MainGroupsPreviewRequestsTab()
}

// MARK: - Groups Tab Preview

private struct MainGroupsPreviewGroupsTab: View {
    @State private var activeTab = 0

    private let mockGroups: [(title: String, members: Int, studies: Int, hasPhoto: Bool)] = [
        ("Young Professionals", 27, 2, true),
        ("Bible Study", 14, 1, false),
        ("Men's Group", 9, 0, false),
        ("Worship Team", 18, 1, true),
        ("Women's Ministry", 22, 3, false),
        ("Youth Group", 35, 2, true),
        ("Prayer Warriors", 12, 1, false),
        ("New Members Class", 8, 1, false),
        ("Marriage Enrichment", 16, 0, true),
        ("College & Career", 20, 2, false),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Groups", "Members", "Enrolled"],
                    activeTab: $activeTab
                )

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(mockGroups.enumerated()), id: \.offset) { i, group in
                            CardGroup(data: CardGroupData(
                                id: "group-\(i)",
                                title: group.title,
                                imageStyle: group.hasPhoto
                                    ? .photo(imageURL: "https://picsum.photos/seed/group\(i)/400/200")
                                    : .icon(systemName: "person.2.fill", backgroundColor: .purple),
                                metadata: {
                                    var items = [DataItem(number: "\(group.members)", label: "Members")]
                                    if group.studies > 0 {
                                        items.append(DataItem(number: "\(group.studies)", label: group.studies == 1 ? "Active Study" : "Active Studies"))
                                    }
                                    return items
                                }(),
                                isSelected: false,
                                onTap: nil
                            ))
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

// MARK: - Members Tab Preview

private struct MainGroupsPreviewMembersTab: View {
    @State private var activeTab = 1
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFocused: Bool

    private let listTopPadding: CGFloat = 60

    private let mockMembers: [(first: String, last: String, avatar: String?, joined: String, groups: [String])] = [
        ("Alexandria", "Ocasio-Cortez", nil, "Jan 15, 2025", ["Young Professionals", "Bible Study"]),
        ("Bob", "Smith", nil, "Dec 10, 2024", ["Men's Group"]),
        ("Caroline", "Zhang", "https://i.pravatar.cc/150?u=caroline", "Mar 22, 2025", ["Worship Team", "Youth Group"]),
        ("David", "Okonkwo", nil, "Feb 1, 2025", ["Bible Study", "Prayer Warriors"]),
        ("Emma", "Davis", "https://i.pravatar.cc/150?u=emma", "Apr 12, 2025", ["Young Professionals"]),
        ("Frank", "Rodriguez", nil, "Nov 3, 2024", ["Men's Group", "Bible Study"]),
        ("Grace", "Kim", "https://i.pravatar.cc/150?u=grace", "May 18, 2025", ["Worship Team"]),
        ("Henry", "Patel", nil, "Aug 22, 2025", ["New Members Class"]),
        ("Isabella", "Thompson", "https://i.pravatar.cc/150?u=isabella", "Jun 5, 2025", ["Women's Ministry"]),
        ("James", "Wilson", nil, "Jul 7, 2025", ["College & Career"]),
        ("Jennifer", "Martinez", "https://i.pravatar.cc/150?u=jennifer", "Sep 14, 2025", ["Young Professionals", "Worship Team"]),
        ("Kevin", "Brown", nil, "Oct 1, 2025", ["Men's Group"]),
        ("Laura", "Chen", "https://i.pravatar.cc/150?u=laura", "Jan 28, 2025", ["Bible Study", "Women's Ministry"]),
        ("Michael", "Nakamura", nil, "Mar 1, 2025", ["Youth Group"]),
        ("Natalie", "Osei", "https://i.pravatar.cc/150?u=natalie", "Feb 20, 2025", ["Prayer Warriors", "Women's Ministry"]),
        ("Oliver", "Wright", nil, "Apr 30, 2025", ["College & Career", "Men's Group"]),
        ("Patricia", "Lopez", "https://i.pravatar.cc/150?u=patricia", "May 5, 2025", ["Marriage Enrichment"]),
        ("Robert", "Williams", nil, "Jun 18, 2025", ["Bible Study"]),
        ("Sarah", "Johnson", "https://i.pravatar.cc/150?u=sarah", "Jul 22, 2025", ["Young Professionals", "Worship Team"]),
        ("Tony", "Stark", "https://i.pravatar.cc/150?u=tony", "Aug 10, 2025", ["Young Professionals"]),
    ]

    private var filteredMembers: [(first: String, last: String, avatar: String?, joined: String, groups: [String])] {
        let sorted = mockMembers.sorted { $0.last.lowercased() < $1.last.lowercased() }
        if searchText.isEmpty { return sorted }
        let q = searchText.lowercased()
        return sorted.filter { "\($0.first) \($0.last)".lowercased().contains(q) }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Groups", "Members", "Enrolled"],
                    activeTab: $activeTab
                )

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: listTopPadding)

                            VStack(spacing: 4) {
                                ForEach(Array(filteredMembers.enumerated()), id: \.offset) { i, member in
                                    CardMember(
                                        data: CardMemberData(
                                            id: "member-\(i)",
                                            firstName: member.first,
                                            lastName: member.last,
                                            avatarURL: member.avatar,
                                            metadata: [DataItem(label: "Joined", value: member.joined)],
                                            groups: member.groups
                                        )
                                    )
                                }
                            }
                            .padding(.horizontal, 16)

                            Spacer().frame(height: 100)
                        }
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 52)
                            Color.black
                        }
                    )

                    SearchField(
                        isActive: $isSearchActive,
                        searchText: $searchText,
                        isFocused: $isSearchFocused,
                        placeholder: "Search members",
                        onClose: { searchText = "" },
                        onClear: { searchText = "" }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Requests Tab Preview

private struct MainGroupsPreviewRequestsTab: View {
    @State private var activeTab = 2

    private let mockRequests: [(first: String, last: String, avatar: String?, group: String, date: String)] = [
        ("New", "Visitor", nil, "Young Professionals", "Feb 28, 2026"),
        ("Rachel", "Adams", "https://i.pravatar.cc/150?u=rachel", "Bible Study", "Mar 1, 2026"),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Groups", "Members", "Enrolled"],
                    activeTab: $activeTab
                )

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(mockRequests.enumerated()), id: \.offset) { i, req in
                            CardMember(
                                data: CardMemberData(
                                    id: "req-\(i)",
                                    firstName: req.first,
                                    lastName: req.last,
                                    avatarURL: req.avatar,
                                    metadata: [
                                        DataItem(label: "Group", value: req.group),
                                        DataItem(label: "Requested", value: req.date)
                                    ],
                                    groups: []
                                )
                            ) {
                                ActionButton(label: "Accept", variant: .purple) {}
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}
