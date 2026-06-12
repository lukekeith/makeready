//
//  Contact.swift
//  MakeReady
//
//  A device/address-book contact (Phase 5.5 — promoted from
//  FixturesManager.ContactFixture, which production code depended on).
//  Populated from CNContactStore by ContactsManager, and decodable from the
//  Debug-only contact fixtures.
//

import Foundation

struct Contact: Codable, Identifiable, Hashable {
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

    // imageData never round-trips JSON — device-only.
    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, phoneNumber, avatarURL
    }

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

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
}
