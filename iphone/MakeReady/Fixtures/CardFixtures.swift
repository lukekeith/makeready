//
//  CardFixtures.swift
//  MakeReady
//
//  Loads card examples from fixtures/cards.json
//

import Foundation
import SwiftUI

// MARK: - JSON Decodable Models

struct CardFixturesJSON: Decodable {
    let study: CardTypeFixtures
    let event: CardTypeFixtures
    let group: CardTypeFixtures
    let video: CardTypeFixtures
}

struct CardTypeFixtures: Decodable {
    let row: [CardFixtureData]
    let mini: [CardFixtureData]
}

struct CardFixtureData: Decodable {
    let id: String
    let title: String
    let subtitle: String?           // For event cards
    let description: String?
    let type: String?               // For study cards
    let category: String?           // For video cards
    let imageStyle: ImageStyleJSON
    let metadata: [MetadataItemJSON]
    let status: String?
}

struct ImageStyleJSON: Decodable {
    let type: String
    let imageURL: String?
    let systemName: String?
    let backgroundColor: String?
    let month: String?
    let day: String?
}

struct MetadataItemJSON: Decodable {
    let icon: String?
    let value: String?
    let number: String?
    let label: String?
}

// MARK: - Card Fixtures Loader

class CardFixtures {
    static let shared = CardFixtures()

    private var fixtures: CardFixturesJSON?

    private init() {
        NSLog("🔵 CardFixtures initializing...")
        loadFixtures()
    }

    private func loadFixtures() {
        NSLog("🔵 Looking for cards.json in bundle...")
        guard let url = Bundle.main.url(forResource: "cards", withExtension: "json") else {
            NSLog("❌ cards.json not found in bundle")
            return
        }

        NSLog("🔵 Found cards.json at: \(url.path)")
        loadFromURL(url)
    }

    private func loadFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            NSLog("🔵 Loaded \(data.count) bytes from cards.json")
            fixtures = try JSONDecoder().decode(CardFixturesJSON.self, from: data)
            NSLog("✅ Successfully decoded card fixtures")
        } catch {
            NSLog("❌ Failed to load/decode card fixtures: \(error)")
        }
    }

    // MARK: - Study Cards

    var studyRowCards: [CardStudyData] {
        let cards = fixtures?.study.row.map { convertToStudyData($0) } ?? []
        print("📊 Loading \(cards.count) study row cards")
        return cards
    }

    var studyMiniCards: [CardStudyData] {
        let cards = fixtures?.study.mini.map { convertToStudyData($0) } ?? []
        print("📊 Loading \(cards.count) study mini cards")
        return cards
    }

    private func convertToStudyData(_ json: CardFixtureData) -> CardStudyData {
        CardStudyData(
            id: json.id,
            title: json.title,
            description: json.description,
            type: json.type,
            imageStyle: convertImageStyle(json.imageStyle),
            metadata: json.metadata.map { convertMetadata($0) },
            status: convertStatus(json.status),
            onTap: nil
        )
    }

    // MARK: - Event Cards

    var eventRowCards: [CardEventData] {
        fixtures?.event.row.map { convertToEventData($0) } ?? []
    }

    var eventMiniCards: [CardEventData] {
        fixtures?.event.mini.map { convertToEventData($0) } ?? []
    }

    private func convertToEventData(_ json: CardFixtureData) -> CardEventData {
        CardEventData(
            id: json.id,
            title: json.title,
            subtitle: json.subtitle,
            imageStyle: convertImageStyle(json.imageStyle),
            metadata: json.metadata.map { convertMetadata($0) },
            status: convertStatus(json.status),
            onTap: nil
        )
    }

    // MARK: - Group Cards

    var groupRowCards: [CardGroupData] {
        fixtures?.group.row.map { convertToGroupData($0) } ?? []
    }

    var groupMiniCards: [CardGroupData] {
        fixtures?.group.mini.map { convertToGroupData($0) } ?? []
    }

    private func convertToGroupData(_ json: CardFixtureData) -> CardGroupData {
        CardGroupData(
            id: json.id,
            title: json.title,
            imageStyle: convertImageStyle(json.imageStyle),
            metadata: json.metadata.map { convertMetadata($0) },
            isSelected: false,
            onTap: nil
        )
    }

    // MARK: - Video Cards

    var videoRowCards: [CardVideoData] {
        fixtures?.video.row.map { convertToVideoData($0) } ?? []
    }

    var videoMiniCards: [CardVideoData] {
        fixtures?.video.mini.map { convertToVideoData($0) } ?? []
    }

    private func convertToVideoData(_ json: CardFixtureData) -> CardVideoData {
        CardVideoData(
            id: json.id,
            title: json.title,
            description: json.description,
            imageStyle: convertImageStyle(json.imageStyle),
            metadata: json.metadata.map { convertMetadata($0) },
            onTap: nil
        )
    }

    // MARK: - Converters

    private func convertImageStyle(_ json: ImageStyleJSON) -> CardImageStyle {
        switch json.type {
        case "photo":
            return .photo(imageURL: json.imageURL ?? "")
        case "icon":
            let color: Color? = {
                switch json.backgroundColor {
                case "purple": return Color.purple
                case "blue": return Color.blue
                case "green": return Color.green
                case "red": return Color.red
                case "orange": return Color.orange
                case .none: return nil
                default: return nil
                }
            }()
            return .icon(systemName: json.systemName ?? "photo", backgroundColor: color)
        case "dateDisplay":
            // dateDisplay takes (day: Int, month: String)
            let day = Int(json.day ?? "1") ?? 1
            let month = json.month ?? "JAN"
            return .dateDisplay(day: day, month: month)
        default:
            return .photo(imageURL: "")
        }
    }

    private func convertMetadata(_ json: MetadataItemJSON) -> DataItem {
        if let icon = json.icon, let value = json.value {
            return DataItem(icon: icon, value: value)
        } else if let number = json.number, let label = json.label {
            return DataItem(number: number, label: label)
        } else {
            return DataItem(icon: "questionmark", value: "")
        }
    }

    private func convertStatus(_ status: String?) -> CardStatus? {
        guard let status = status else { return nil }
        switch status {
        case "confirmed": return .confirmed
        case "pending": return .pending
        case "new": return .new
        default: return nil
        }
    }

    // MARK: - Lesson Cards

    var lessonCards: [CardLessonData] {
        [
            // No activities
            CardLessonData(
                id: "lesson-1",
                day: 1,
                activities: [],
                onTap: nil
            ),
            // 1 activity
            CardLessonData(
                id: "lesson-2",
                day: 2,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Romans 1:1-2")
                ],
                onTap: nil
            ),
            // 2 activities
            CardLessonData(
                id: "lesson-3",
                day: 3,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Romans 1:1-2"),
                    LessonActivityData(icon: "play.fill", type: "Video", title: "3:00")
                ],
                onTap: nil
            ),
            // 3 activities
            CardLessonData(
                id: "lesson-4",
                day: 4,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Romans 1:1-2"),
                    LessonActivityData(icon: "play.fill", type: "Video", title: "3:00"),
                    LessonActivityData(icon: "person.2", type: "Review", title: "3:00")
                ],
                onTap: nil
            )
        ]
    }
}
