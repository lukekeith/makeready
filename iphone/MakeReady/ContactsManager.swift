//
//  ContactsManager.swift
//  MakeReady
//
//  Contacts manager - loads from device with permission
//

import SwiftUI
import Contacts

class ContactsManager: ObservableObject {
    @Published var contacts: [FixturesManager.ContactFixture] = []
    @Published var hasPermission: Bool = false
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var searchQuery: String = ""

    private let contactStore = CNContactStore()

    init() {
        NSLog("📱 ContactsManager: Initializing...")
        checkPermission()
    }

    func checkPermission() {
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        hasPermission = (permissionStatus == .authorized)

        NSLog("📱 ContactsManager: Permission status: \(permissionStatus.rawValue)")

        if hasPermission {
            loadContacts()
        }
    }

    func requestPermission() async {
        NSLog("📱 ContactsManager: Requesting permission...")
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            await MainActor.run {
                self.permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
                self.hasPermission = granted
                NSLog("📱 ContactsManager: Permission granted: \(granted)")
                if granted {
                    loadContacts()
                }
            }
        } catch {
            NSLog("❌ ContactsManager: Error requesting permission: \(error)")
        }
    }

    func loadContacts() {
        NSLog("📱 ContactsManager: Loading contacts from device...")

        let store = contactStore
        DispatchQueue.global(qos: .userInitiated).async {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var fetchedContacts: [FixturesManager.ContactFixture] = []

            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    guard !contact.givenName.isEmpty || !contact.familyName.isEmpty else {
                        return
                    }

                    let phoneNumber = contact.phoneNumbers.first?.value.stringValue
                    let imageData = contact.thumbnailImageData ?? contact.imageData

                    let fixture = FixturesManager.ContactFixture(
                        id: contact.identifier,
                        firstName: contact.givenName.isEmpty ? nil : contact.givenName,
                        lastName: contact.familyName.isEmpty ? nil : contact.familyName,
                        phoneNumber: phoneNumber,
                        avatarURL: nil,
                        imageData: imageData
                    )

                    fetchedContacts.append(fixture)
                }

                let sorted = fetchedContacts.sorted { $0.fullName < $1.fullName }
                DispatchQueue.main.async {
                    self.contacts = sorted
                    NSLog("✅ ContactsManager: Loaded \(sorted.count) contacts from device (contacts without names excluded)")
                }
            } catch {
                NSLog("❌ ContactsManager: Error fetching contacts: \(error)")
            }
        }
    }

    var filteredContacts: [FixturesManager.ContactFixture] {
        if searchQuery.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.fullName.lowercased().contains(searchQuery.lowercased())
        }
    }

    var sectionedContacts: [(String, [FixturesManager.ContactFixture])] {
        let grouped = Dictionary(grouping: filteredContacts) { contact in
            contact.fullName.prefix(1).uppercased()
        }

        return grouped.map { (letter, contacts) in
            (letter, contacts.sorted { $0.fullName < $1.fullName })
        }.sorted { $0.0 < $1.0 }
    }

    var alphabetLetters: [String] {
        Array(Set(contacts.map { String($0.fullName.prefix(1).uppercased()) })).sorted()
    }

    func scrollToLetter(_ letter: String) -> FixturesManager.ContactFixture? {
        return filteredContacts.first { $0.fullName.prefix(1).uppercased() == letter }
    }
}

// Group Fixture Manager - loads from fixtures (legacy, use GroupActions for API)
class GroupFixtureManager: ObservableObject {
    struct GroupFixture: Identifiable {
        let id = UUID()
        let name: String
        let memberCount: Int
    }

    @Published var groups: [GroupFixture] = []
    @Published var selectedGroup: GroupFixture?

    init() {
        loadGroups()
    }

    func loadGroups() {
        // For now, hardcoded until we create groups.json fixture
        groups = [
            GroupFixture(name: "Youth Group", memberCount: 12),
            GroupFixture(name: "Sunday Service", memberCount: 45),
            GroupFixture(name: "Bible Study", memberCount: 8),
            GroupFixture(name: "Worship Team", memberCount: 15),
        ]
        selectedGroup = groups.first
    }
}
