//
//  GroupSelectorSheet.swift
//  MakeReady
//
//  Sheet for selecting which group to invite contacts to
//

import SwiftUI

struct GroupSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupManager = GroupFixtureManager()
    @Binding var selectedGroup: GroupFixtureManager.GroupFixture?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Group list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupManager.groups) { group in
                                groupRow(group)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white50)
                            .font(Typography.s24)
                    }
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Group Row
    private func groupRow(_ group: GroupFixtureManager.GroupFixture) -> some View {
        Button(action: {
            selectedGroup = group
            groupManager.selectedGroup = group
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Text("\(group.memberCount) members")
                        .font(Typography.s15)
                        .foregroundColor(.white50)
                }

                Spacer()

                // Checkmark if selected
                if selectedGroup?.id == group.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.brandPrimary)
                        .font(Typography.s24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedGroup?.id == group.id ? Color.white10 : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var selectedGroup: GroupFixtureManager.GroupFixture? = nil
    GroupSelectorSheet(selectedGroup: $selectedGroup)
}
