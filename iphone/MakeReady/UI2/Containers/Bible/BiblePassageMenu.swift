import Foundation

/// bible-verse-picker D12/D13/D11: the menu a tap on locked scripture opens, its two confirmations, and the document
/// operations Change passage needs. The overlays are C-066 `ActionMenuOverlay`s presented through
/// `actionMenuPresentation`, as `ActivitySlideMenu` does for the program-home rail.
enum BiblePassageMenu {
    /// D12: Change passage · Highlight, the rows d2m ships for a locked object.
    static let items: [ActionMenuOverlay.ActionItem] = ActivitiesEditorScreen.lockedObjectMenuRows.map {
        .init(glyph: $0.glyph, label: $0.label)
    }

    /// A C-066 confirmation: its title, message, the one action and the Cancel label.
    struct Confirmation: Equatable {
        let title: String
        let message: String
        let confirm: String
        let cancel: String
        let destructive: Bool

        var action: ActionMenuOverlay.ActionItem {
            .init(glyph: "", label: confirm, tone: destructive ? .destructive : .standard)
        }
    }

    /// What the editor is showing over the canvas, if anything.
    enum Presentation: Equatable {
        /// D12: the object tapped.
        case menu(object: Int)
        /// D13: a change that removes highlights asks first.
        case change(Confirmation)
        /// D11/D34: deleting the locked scripture asks first (the reference deletes as ordinary text, with no question).
        case delete(Confirmation)
    }

    /// D13: "2 highlights are outside the new passage and will be removed" (singular for one).
    static func changeConfirmation(removed: Int) -> Confirmation {
        let subject = removed == 1 ? "1 highlight is" : "\(removed) highlights are"
        return Confirmation(title: "Change passage?", message: "\(subject) outside the new passage and will be removed",
                            confirm: "Change", cancel: "Cancel", destructive: false)
    }

    /// D11/D34: deleting the scripture deletes the whole passage; the reference text object stays.
    static let deleteConfirmation = Confirmation(
        title: "Delete passage?", message: "The scripture and its highlights are removed. This can't be undone.",
        confirm: "Delete passage", cancel: "Cancel", destructive: true)
}

/// The scripture document's pieces Change passage reads and rewrites.
enum BiblePassageEditing {
    /// The passage the activity holds, rebuilt as a pick so D13 can re-anchor against it. Only each verse's length
    /// and position matter to re-anchoring, so the first verse is padded back to its canonical offset.
    static func currentPick(of document: ActivityDocument) -> BiblePick? {
        guard let passage = document.passages.first, passage.chapterStart == passage.chapterEnd,
              let scripture = document.textObjects.first(where: { $0.role == "scripture" }) else { return nil }
        let lines = scripture.text.components(separatedBy: "\n")
        guard lines.count == passage.verseEnd - passage.verseStart + 1 else { return nil }
        let verses = lines.enumerated().map { offset, line in
            let pad = offset == 0 ? String(repeating: " ", count: passage.startOffset ?? 0) : ""
            return BibleVerse(verse: passage.verseStart + offset, text: pad + line)
        }
        return BiblePick(passage: passage, verses: verses, bookName: bookName(of: document, passage: passage))
    }

    /// The book name the reference reads with: the document's fallback title is the reference without the translation
    /// (D10), so the name is whatever precedes the chapter — kept only when it rebuilds that title exactly.
    private static func bookName(of document: ActivityDocument, passage: BiblePassage) -> String {
        guard case .string(let title)? = document.raw[path: ["fallback", "title"]],
              let space = title.lastIndex(of: " ") else { return "" }
        let name = String(title[..<space])
        return BibleScripture.title(for: passage, bookName: name) == title ? name : ""
    }

    /// The scripture object's highlights (the reference is ordinary text and keeps its own, D34).
    static func highlights(of document: ActivityDocument) -> [TextObject.Highlight] {
        document.textObjects.first { $0.role == "scripture" }?.highlights ?? []
    }

    /// `document` with the scripture object's highlights replaced.
    static func setting(highlights: [TextObject.Highlight], in document: ActivityDocument) -> ActivityDocument {
        guard let index = ActivitiesEditorMapper.rawObjects(document).firstIndex(where: { isRole("scripture", $0) }) else { return document }
        return setting(highlights: highlights, at: index, in: document)
    }

    /// `document` with object `index`'s highlights replaced; every other field of the object is untouched.
    static func setting(highlights: [TextObject.Highlight], at index: Int, in document: ActivityDocument) -> ActivityDocument {
        guard ActivitiesEditorMapper.rawObjects(document).indices.contains(index),
              let data = try? JSONEncoder().encode(highlights),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data) else { return document }
        return document.updating { $0[path: ["content", "objects", .index(index), "highlights"]] = json }
    }

    /// D11/D13/D34: `current` with only the passage replaced from `fresh` (a D10 document for the new passage): the
    /// scripture object's `text`, `startNumber`, `reference` and `highlights`, the reference object's `text` only while
    /// it still reads as the old passage's reference (`BibleScripture.citationAfterChange`), the passages and the
    /// fallback title. Every other field and object — moves, restyling, objects the leader added or deleted, the page's
    /// actions — is kept. A document missing its scripture object takes `fresh` whole.
    static func replacingPassage(in current: ActivityDocument, with fresh: ActivityDocument,
                                 old: BiblePick, new: BiblePick) -> ActivityDocument {
        let objects = ActivitiesEditorMapper.rawObjects(current), freshObjects = ActivitiesEditorMapper.rawObjects(fresh)
        guard let scripture = objects.firstIndex(where: { isRole("scripture", $0) }),
              let newScripture = freshObjects.first(where: { isRole("scripture", $0) }) else { return fresh }
        var updated = current.updating { raw in
            for key in ["text", "startNumber", "reference", "highlights"] {
                raw[path: ["content", "objects", .index(scripture), .key(key)]] = newScripture[path: [.key(key)]]
            }
            if let citation = objects.firstIndex(where: { isRole("citation", $0) }),
               case .string(let text)? = objects[citation][path: ["text"]] {
                raw[path: ["content", "objects", .index(citation), "text"]] =
                    .string(BibleScripture.citationAfterChange(current: text, old: old, new: new))
            }
            raw[path: ["fallback", "title"]] = fresh.raw[path: ["fallback", "title"]]
        }
        updated.passages = fresh.passages
        return updated
    }

    /// The document without its scripture object or its passages (D11); the reference text object stays (D34).
    static func removingPassage(from document: ActivityDocument) -> ActivityDocument {
        let kept = ActivitiesEditorMapper.rawObjects(document).filter { !isRole("scripture", $0) }
        var updated = document.updating { $0[path: ["content", "objects"]] = .array(kept) }
        updated.passages = []
        return updated
    }

    private static func isRole(_ role: String, _ object: JSONValue) -> Bool {
        if case .string(let value)? = object[path: ["role"]] { return value == role }
        return false
    }
}
