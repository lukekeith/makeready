//
//  SearchContactsPage.swift
//  MakeReady
//
//  Search contacts with active state and filters (Figma 872-13904)
//

import SwiftUI

struct SearchContactsPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactsManager = ContactsManager()
    @State private var showAlert = false
    @State private var selectedContactName = ""

    // Filtered contacts based on search
    private var displayedContacts: [FixturesManager.ContactFixture] {
        contactsManager.filteredContacts
    }

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            SearchableList(
                items: displayedContacts,
                filterPredicate: { contact, query in
                    contact.fullName.lowercased().contains(query.lowercased())
                },
                placeholder: "Search contacts",
                showAlphabetScrubber: true,
                sectionKeyPath: \.fullName
            ) { contact in
                contactRow(contact)
            } header: {
                header
            }
        }
        .alert("Invitation", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("SMS invitation will be sent to \(selectedContactName)")
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(Typography.s20)
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
            }

            Spacer()

            // Title
            Text("Invite contacts")
                .font(Typography.s17Bold)
                .foregroundColor(.white)

            Spacer()

            // Done button
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(Typography.s17)
                    .foregroundColor(.brandPrimary)
            }
            .frame(width: 60, height: 40)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    // MARK: - Contact Row
    private func contactRow(_ contact: FixturesManager.ContactFixture) -> some View {
        CardContact(
            data: CardContactData(
                id: contact.id,
                firstName: contact.firstName ?? "",
                lastName: contact.lastName ?? "",
                avatarURL: contact.avatarURL,
                imageData: contact.imageData,
                onTap: nil
            )
        ) {
            if contact.hasPhoneNumber {
                ActionButton(label: "Invite", variant: .purple) {
                    selectedContactName = contact.fullName
                    showAlert = true
                }
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    SearchContactsPagePreview()
}

private struct SearchContactsPagePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var selectedContactName = ""
    
    private let mockContacts: [FixturesManager.ContactFixture] = [
        FixturesManager.ContactFixture(id: "1", firstName: "Alice", lastName: "Anderson", phoneNumber: "555-0101", avatarURL: "https://i.pravatar.cc/150?u=alice", imageData: nil),
        FixturesManager.ContactFixture(id: "2", firstName: "Bob", lastName: "Brown", phoneNumber: "555-0102", avatarURL: "https://i.pravatar.cc/150?u=bob", imageData: nil),
        FixturesManager.ContactFixture(id: "3", firstName: "Charlie", lastName: "Chen", phoneNumber: "555-0103", avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "4", firstName: "Diana", lastName: "Davis", phoneNumber: nil, avatarURL: "https://i.pravatar.cc/150?u=diana", imageData: nil),
        FixturesManager.ContactFixture(id: "5", firstName: "Emily", lastName: "Evans", phoneNumber: "555-0105", avatarURL: "https://i.pravatar.cc/150?u=emily", imageData: nil),
        FixturesManager.ContactFixture(id: "6", firstName: "Frank", lastName: "Foster", phoneNumber: "555-0106", avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "7", firstName: "Grace", lastName: "Garcia", phoneNumber: nil, avatarURL: "https://i.pravatar.cc/150?u=grace", imageData: nil),
        FixturesManager.ContactFixture(id: "8", firstName: "Henry", lastName: "Harris", phoneNumber: "555-0108", avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "9", firstName: "Iris", lastName: "Irving", phoneNumber: "555-0109", avatarURL: "https://i.pravatar.cc/150?u=iris", imageData: nil),
        FixturesManager.ContactFixture(id: "10", firstName: "Jack", lastName: "Johnson", phoneNumber: "555-0110", avatarURL: "https://i.pravatar.cc/150?u=jack", imageData: nil),
        FixturesManager.ContactFixture(id: "11", firstName: "Karen", lastName: "King", phoneNumber: "555-0111", avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "12", firstName: "Leo", lastName: "Lopez", phoneNumber: nil, avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "13", firstName: "Maria", lastName: "Martinez", phoneNumber: "555-0113", avatarURL: "https://i.pravatar.cc/150?u=maria", imageData: nil),
        FixturesManager.ContactFixture(id: "14", firstName: "Nathan", lastName: "Nelson", phoneNumber: "555-0114", avatarURL: nil, imageData: nil),
        FixturesManager.ContactFixture(id: "15", firstName: "Olivia", lastName: "Owen", phoneNumber: "555-0115", avatarURL: "https://i.pravatar.cc/150?u=olivia", imageData: nil),
    ]
    
    private var header: some View {
        HStack(spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(Typography.s20)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text("Invite contacts")
                .font(Typography.s17Bold)
                .foregroundColor(.white)
            Spacer()
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(Typography.s17)
                    .foregroundColor(.brandPrimary)
            }
            .frame(width: 60, height: 40)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            SearchableList(
                items: mockContacts,
                filterPredicate: { contact, query in
                    contact.fullName.lowercased().contains(query.lowercased())
                },
                placeholder: "Search contacts",
                showAlphabetScrubber: true,
                sectionKeyPath: \.fullName
            ) { contact in
                CardContact(
                    data: CardContactData(
                        id: contact.id,
                        firstName: contact.firstName ?? "",
                        lastName: contact.lastName ?? "",
                        avatarURL: contact.avatarURL,
                        imageData: contact.imageData,
                        onTap: nil
                    )
                ) {
                    if contact.hasPhoneNumber {
                        ActionButton(label: "Invite", variant: .purple) {
                            selectedContactName = contact.fullName
                            showAlert = true
                        }
                    } else {
                        EmptyView()
                    }
                }
            } header: {
                header
            }
        }
        .alert("Invitation", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("SMS invitation will be sent to \(selectedContactName)")
        }
    }
}
