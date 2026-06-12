//
//  FixturesManager.swift
//  MakeReady
//
//  Manager for loading test fixtures from JSON files. DEBUG-ONLY (Phase
//  5.5): the release binary ships no fixture code. The `Contact` model it
//  used to own lives in State/Models/Contact.swift — production code
//  (ContactsManager) uses that, never this.
//

#if DEBUG

import Foundation

class FixturesManager {
    static let shared = FixturesManager()

    private init() {}

    // MARK: - Contact Fixtures

    struct ContactsData: Codable {
        let contacts: [Contact]
    }

    func loadContacts() -> [Contact] {
        NSLog("🔍 FixturesManager: Starting to load contacts...")

        // Try loading from Fixtures subdirectory first
        if let url = Bundle.main.url(forResource: "contacts", withExtension: "json", subdirectory: "Fixtures") {
            NSLog("✅ Found contacts.json at: %@", url.absoluteString)
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(ContactsData.self, from: data)
                NSLog("✅ Loaded %d contacts from fixtures", decoded.contacts.count)
                return decoded.contacts
            } catch {
                NSLog("❌ Error decoding contacts.json: %@", error.localizedDescription)
            }
        } else {
            NSLog("⚠️ Could not find contacts.json in Fixtures subdirectory, trying root...")

            // Try without subdirectory
            if let url = Bundle.main.url(forResource: "contacts", withExtension: "json") {
                NSLog("✅ Found contacts.json at root: %@", url.absoluteString)
                do {
                    let data = try Data(contentsOf: url)
                    let decoded = try JSONDecoder().decode(ContactsData.self, from: data)
                    NSLog("✅ Loaded %d contacts from root", decoded.contacts.count)
                    return decoded.contacts
                } catch {
                    NSLog("❌ Error decoding contacts.json from root: %@", error.localizedDescription)
                }
            } else {
                NSLog("❌ Could not find contacts.json anywhere in bundle")
            }
        }

        NSLog("⚠️ Returning empty contacts array")
        return []
    }

    // MARK: - Member Fixtures

    struct MemberFixture: Codable, Identifiable {
        let id: String
        let firstName: String?
        let lastName: String?
        let avatarURL: String?
        let birthDate: String?  // ISO date string
        let joinDate: String?   // ISO date string
        let groups: [String]

        var fullName: String {
            let parts = [firstName, lastName].compactMap { $0 }
            return parts.joined(separator: " ")
        }

        var birthDateAsDate: Date? {
            guard let birthDate = birthDate else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: birthDate)
        }

        var joinDateAsDate: Date? {
            guard let joinDate = joinDate else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: joinDate)
        }

        var age: Int? {
            guard let birthDate = birthDateAsDate else { return nil }
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
            return ageComponents.year
        }
    }

    struct MembersData: Codable {
        let members: [MemberFixture]
    }

    func loadMembers() -> [MemberFixture] {
        // Try loading from Fixtures subdirectory first
        if let url = Bundle.main.url(forResource: "members", withExtension: "json", subdirectory: "Fixtures") {
            print("✅ Found members.json at: \(url)")
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(MembersData.self, from: data)
                print("✅ Loaded \(decoded.members.count) members from fixtures")
                return decoded.members
            } catch {
                print("❌ Error decoding members.json: \(error)")
            }
        } else {
            print("❌ Could not find members.json in Fixtures subdirectory")

            // Try without subdirectory
            if let url = Bundle.main.url(forResource: "members", withExtension: "json") {
                print("✅ Found members.json at root: \(url)")
                do {
                    let data = try Data(contentsOf: url)
                    let decoded = try JSONDecoder().decode(MembersData.self, from: data)
                    print("✅ Loaded \(decoded.members.count) members from root")
                    return decoded.members
                } catch {
                    print("❌ Error decoding members.json: \(error)")
                }
            } else {
                print("❌ Could not find members.json anywhere in bundle")
            }
        }

        return []
    }
}

#endif
