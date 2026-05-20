//
//  FixturesManager.swift
//  MakeReady
//
//  Manager for loading test fixtures from JSON files
//

import Foundation

class FixturesManager {
    static let shared = FixturesManager()

    private init() {}

    // MARK: - Contact Fixtures

    struct ContactFixture: Codable, Identifiable, Hashable {
        let id: String
        let firstName: String?
        let lastName: String?
        let phoneNumber: String?
        let avatarURL: String?
        var imageData: Data? = nil // For real contacts from device

        var fullName: String {
            let parts = [firstName, lastName].compactMap { $0 }
            return parts.joined(separator: " ")
        }

        var initials: String? {
            let first = firstName?.prefix(1).uppercased() ?? ""
            let last = lastName?.prefix(1).uppercased() ?? ""

            if !first.isEmpty && !last.isEmpty {
                return first + last
            } else if !first.isEmpty {
                return first
            } else if !last.isEmpty {
                return last
            }
            return nil
        }

        var hasPhoneNumber: Bool {
            phoneNumber != nil && !(phoneNumber?.isEmpty ?? true)
        }

        // Custom CodingKeys to handle optional imageData
        enum CodingKeys: String, CodingKey {
            case id, firstName, lastName, phoneNumber, avatarURL
        }

        // Custom init for real contacts (not from JSON)
        init(id: String, firstName: String?, lastName: String?, phoneNumber: String?, avatarURL: String?, imageData: Data? = nil) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.phoneNumber = phoneNumber
            self.avatarURL = avatarURL
            self.imageData = imageData
        }

        // MARK: - Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: ContactFixture, rhs: ContactFixture) -> Bool {
            lhs.id == rhs.id
        }
    }

    struct ContactsData: Codable {
        let contacts: [ContactFixture]
    }

    func loadContacts() -> [ContactFixture] {
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
