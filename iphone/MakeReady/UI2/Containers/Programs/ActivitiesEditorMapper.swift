import SwiftUI
import UIKit

/// text-activity D17/D18/D33: the editor's pure mapping. A document and its media map become
/// `ActivitiesEditorScreen.State`; each screen edit becomes a patch on the document's raw JSON that
/// touches only the edited fields, so every field this build doesn't edit (or doesn't know) is saved
/// back unchanged (D11, D33).
enum ActivitiesEditorMapper {

    /// A new object's size in wu — the screen's §3 default.
    static let newObjectSize = 38.0
    /// The edit slot's width and centre x, in wu.
    static let slotWidth = 392.0
    static let slotCenterX = 220.0

    // MARK: - Document → State

    /// The screen's Idle state for `document`. The container sets the mode, the edited index and the
    /// save/load flags on top. D17: the highlight tool, the effects tool and the eyedropper are off.
    static func state(document: ActivityDocument, media: [String: MediaMapEntry], slides: [ContentActivity],
                      activeID: String, kind: String = "text") -> ActivitiesEditorScreen.State {
        // D26: a `bible` activity's scripture and citation are placed by the page, never by their `transform`.
        let placed = BibleScripture.placed(document)
        let objects = placed.objects
        let raw = rawObjects(document)
        let background = document.background
        let image = background.image
        let actions = document.actions
        var highlights: [(id: String, object: Int, start: Int, end: Int)] = []
        for (index, object) in objects.enumerated() {
            for highlight in object.highlights {
                highlights.append((highlight.id, index, highlight.start, highlight.end))
            }
        }
        let ordered = slides.sorted { $0.position < $1.position }
        // bible-verse-picker D21: only a `bible` activity shows the highlight tool; its referenced scripture and
        // citation are locked (D11), a legacy object without `reference` is ordinary text (D23).
        var state = ActivitiesEditorScreen.State(
            editorMode: "idle",
            openTool: "",
            showsHighlightTool: kind == "bible",
            showsEffectsTool: false,
            showsEyedropper: false,
            slideIDs: ordered.map(\.id),
            slideLabels: ordered.map(\.title),
            slideImages: slideImages(slides, media: media),
            activeID: activeID,
            objectTexts: objects.map(\.text),
            objectFonts: objects.map { fontKey($0.font) },
            objectColors: objects.map(\.color),
            objectWeights: objects.map { weightName($0.weight) },
            objectSizes: objects.map(\.size),
            objectAlignments: objects.map(\.alignment),
            objectListStyles: raw.indices.map { string(raw[$0], "listStyle") ?? "none" },
            objectStartNumbers: raw.indices.map { number(raw[$0], "startNumber").map { Int($0) } ?? 1 },
            objectXs: objects.map(\.transform.x),
            objectYs: objects.map(\.transform.y),
            objectScales: objects.map(\.transform.scale),
            objectRotations: objects.map(\.transform.rotation),
            objectWidths: objects.map(\.transform.width),
            objectHeights: [],
            editingIndex: -1,
            pageColorHex: background.color,
            pageImageURL: image.flatMap { media[$0.mediaId]?.url } ?? "",
            pageImageFocalX: image?.focal?.x ?? 0.5,
            pageImageFocalY: image?.focal?.y ?? 0.5,
            pageWashHex: background.wash?.color ?? "",
            pageWashOpacity: background.wash?.opacity ?? 0,
            verseTexts: [],
            firstVerse: 1,
            highlightIDs: highlights.map(\.id),
            highlightObjects: highlights.map(\.object),
            highlightStarts: highlights.map(\.start),
            highlightEnds: highlights.map(\.end),
            selectedHighlightID: "",
            actionIDs: actions.map(\.id),
            actionKinds: actions.map(\.kind.rawValue),
            actionLabels: actions.map(\.label),
            actionPlacements: actions.map(\.placement.rawValue),
            actionValues: actions.map { prefill($0).value },
            actionBodies: actions.map { prefill($0).body },
            centerGuide: false,
            deleteTargetShown: false,
            saving: false,
            saveFailed: false,
            loadFailed: false
        )
        state.objectIDs = objects.map(\.id)
        state.objectLocks = document.textObjects.map(\.isLockedScripture)
        if kind == "bible", let layout = placed.layout { applyBibleLayout(layout, objects: objects, to: &state) }
        return state
    }

    /// D26–D29: the page's layout for a `bible` activity — the five-tool row, the page's height, which objects the page
    /// places (with their measured heights) and the style panel seeded from the scripture. Animation stays hidden (D28).
    private static func applyBibleLayout(_ layout: BibleScripture.PageLayout, objects: [TextObject],
                                         to state: inout ActivitiesEditorScreen.State) {
        let laidOut = objects.indices.map { $0 == layout.scriptureIndex || $0 == layout.citationIndex }
        state.isBible = true
        state.pageHeight = CGFloat(layout.height)
        state.objectPageLaidOut = laidOut
        state.objectHeights = objects.indices.map { index in
            if index == layout.scriptureIndex { return layout.scripture.height }
            if index == layout.citationIndex { return layout.citation?.height ?? 0 }
            return 0
        }
        let scripture = objects[layout.scriptureIndex]
        state.bibleFace = fontKey(scripture.font)
        state.bibleWeight = scripture.weight < 450 ? 400 : scripture.weight < 600 ? 500 : 700
        state.bibleSize = CGFloat(scripture.size)
        state.bibleLineHeight = CGFloat(scripture.lineHeight)
        state.bibleInset = CGFloat(scripture.inset ?? BibleScripture.defaultInset)
        state.bibleVerseNumbers = (scripture.verseNumbers ?? .inline).rawValue
    }

    /// D18: the document's font keys, passed to the screen as keys — it draws `display`, `sans`,
    /// `serif`, `mono` as Poppins, Inter, Source Serif 4 and Courier Prime. An unknown key is `sans`.
    static let fontKeys = ["display", "sans", "serif", "mono"]

    static func fontKey(_ key: String) -> String { fontKeys.contains(key) ? key : "sans" }

    /// 02 §3 weights 400 · 500 · 700 → the screen's `regular` · `medium` · `bold`.
    static func weightName(_ weight: Int) -> String {
        switch weight {
        case ..<450: return "regular"
        case ..<600: return "medium"
        default: return "bold"
        }
    }

    /// Whether the editor can open this document: a canvas this build reads. Anything else (a newer
    /// schema, a malformed one) would lose fields it can't show, so the editor reports a load failure.
    static func isEditable(_ document: ActivityDocument) -> Bool {
        if case .canvas = document.renderable { return true }
        return false
    }

    // MARK: - D16: untouched


    // MARK: - D33: edits → document patches

    /// One object edit, written into that object's raw JSON field by field.
    static func apply(_ edit: ActivitiesEditorScreen.ObjectEdit, to doc: ActivityDocument) -> ActivityDocument {
        guard rawObjects(doc).indices.contains(edit.index) else { return doc }
        let base: [JSONPathComponent] = ["content", "objects", .index(edit.index)]
        return doc.updating { raw in
            if let text = edit.text { raw[path: base + ["text"]] = .string(text) }
            if let font = edit.font { raw[path: base + ["font"]] = .string(font) }
            if let weight = edit.weight { raw[path: base + ["weight"]] = .number(Double(weight)) }
            if let size = edit.size { raw[path: base + ["size"]] = .number(Double(size)) }
            if let color = edit.color { raw[path: base + ["color"]] = .string(color) }
            if let alignment = edit.alignment { raw[path: base + ["alignment"]] = .string(alignment) }
            if let width = edit.width { raw[path: base + ["transform", "width"]] = .number(Double(width)) }
            if let transform = edit.transform {
                raw[path: base + ["transform", "x"]] = .number(Double(transform.x))
                raw[path: base + ["transform", "y"]] = .number(Double(transform.y))
                raw[path: base + ["transform", "scale"]] = .number(Double(transform.scale))
                raw[path: base + ["transform", "rotation"]] = .number(Double(transform.rotation))
            }
        }
    }

    /// A tap on the empty canvas: a new, empty object at the tap's height, appended last (on top).
    /// Its colour contrasts with the page so the leader sees what they type.
    static func appendObject(to doc: ActivityDocument, centerY: Double) -> (document: ActivityDocument, index: Int) {
        let objects = rawObjects(doc)
        let object: JSONValue = .object([
            "id": .string("o" + UUID().uuidString.prefix(8).lowercased()),
            "role": .string("body"),
            "text": .string(""),
            "font": .string("sans"),
            "weight": .number(700),
            "size": .number(newObjectSize),
            "lineHeight": .number(1.25),
            "color": .string(isLight(doc.background.color) ? "#000000" : "#FFFFFF"),
            "alignment": .string("center"),
            "transform": .object([
                "x": .number(slotCenterX), "y": .number(centerY), "width": .number(slotWidth),
                "scale": .number(1), "rotation": .number(0)
            ]),
            "marks": .array([]),
            "highlights": .array([])
        ])
        let updated = doc.updating { $0[path: ["content", "objects"]] = .array(objects + [object]) }
        return (updated, objects.count)
    }

    /// Removes one object (a new object Done leaves empty).
    static func removeObject(at index: Int, from doc: ActivityDocument) -> ActivityDocument {
        var objects = rawObjects(doc)
        guard objects.indices.contains(index) else { return doc }
        objects.remove(at: index)
        return doc.updating { $0[path: ["content", "objects"]] = .array(objects) }
    }

    /// The text of one object, read from the document.
    static func text(at index: Int, in doc: ActivityDocument) -> String? {
        let objects = rawObjects(doc)
        guard objects.indices.contains(index) else { return nil }
        return string(objects[index], "text")
    }

    // MARK: - text-activity-v2 round 6: the chips' screenshots

    /// The editor's chips, as the program-home rail sees them: each activity in lesson order as a summary.
    static func slideSummaries(_ slides: [ContentActivity]) -> [ActivitySummary] {
        slides.sorted { $0.position < $1.position }.map {
            ActivitySummary(id: $0.id, activityKey: $0.activityKey, position: $0.position, kind: $0.kind,
                            title: $0.title, document: $0.document)
        }
    }

    /// Each chip's screenshot URL, parallel to the chips ("" = none): the rendered thumbnail for a canvas
    /// kind, the poster for a video, the still for YouTube — the program-home rail's own rule.
    static func slideImages(_ slides: [ContentActivity], media: [String: MediaMapEntry]) -> [String] {
        slideSummaries(slides).map { StudyProgramHomeMapper.slideImage($0, media: media) }
    }

    // MARK: - text-activity-v2: the Background rail's state (D13, D14, D22)

    /// The Background rail's fields on top of `state()`: the selected option, the gradient (hidden
    /// flag included, so the canvas draws exactly the visible one), the 12 palettes (darkest first),
    /// and the library's photos newest first.
    static func withBackgroundRail(_ state: ActivitiesEditorScreen.State, document: ActivityDocument,
                                   library: [MediaLibraryItem], hasMoreImages: Bool) -> ActivitiesEditorScreen.State {
        var state = state
        switch backgroundOption(of: document) {
        case .gradient: state.backgroundOption = "gradient"
        case .colour: state.backgroundOption = "colour"
        case .image: state.backgroundOption = "image"
        }
        state.gradient = document.background.gradient.map { gradient in
            .init(base: gradient.base, hidden: gradient.hidden,
                  blobs: gradient.blobs.map { .init(x: $0.x, y: $0.y, r: $0.r, color: $0.color) })
        }
        state.palettes = ActivityBackgroundPalettes.all.map { palette in
            let base = ActivityBackgroundPalettes.darkest(palette)
            return [base] + palette.filter { $0 != base }
        }
        state.libraryImages = library
            .filter { $0.type == "photo" }
            .sorted { $0.createdAt > $1.createdAt }
            .map { .init(id: $0.id, thumbnailURL: $0.thumbnailUrl ?? $0.url) }
        state.hasMoreImages = hasMoreImages
        return state
    }

    /// The Image rail's canvas drag: the focal point, kept only when an image is set (0–1, clamped).
    static func settingFocal(x: Double, y: Double, in doc: ActivityDocument) -> ActivityDocument {
        guard doc.background.image != nil else { return doc }
        return doc.updating {
            $0[path: ["background", "image", "focal"]] = .object(["x": .number(min(max(x, 0), 1)),
                                                                   "y": .number(min(max(y, 0), 1))])
        }
    }

    /// The Image rail's wash: colour + opacity over an image; an empty colour removes it.
    static func settingWash(color: String, opacity: Double, in doc: ActivityDocument) -> ActivityDocument {
        guard doc.background.image != nil else { return doc }
        return doc.updating { raw in
            if color.isEmpty {
                raw[path: ["background", "wash"]] = nil
            } else {
                raw[path: ["background", "wash"]] = .object(["color": .string(color), "opacity": .number(min(max(opacity, 0), 1))])
            }
        }
    }

    // MARK: - text-activity-v2: Cancel and the Actions rail (D19)

    /// The document with object `index` replaced by `object` (raw JSON, unknown fields included).
    static func replacingObject(at index: Int, with object: JSONValue, in doc: ActivityDocument) -> ActivityDocument {
        doc.updating { raw in
            var objects = rawObjects(doc)
            guard objects.indices.contains(index) else { return }
            objects[index] = object
            raw[path: ["content", "objects"]] = .array(objects)
        }
    }

    /// D19: an action still without a label when its rail closes is dropped; every other action stays as it is.
    static func droppingUnlabelledActions(in doc: ActivityDocument) -> ActivityDocument {
        let actions = rawActions(doc)
        let kept = actions.filter { !(string($0, "label") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard kept.count != actions.count else { return doc }
        return doc.updating { $0[path: ["actions"]] = .array(kept) }
    }

    // MARK: - text-activity-v2: the Background rail's gradient operations (D13, D14, D17, D18)

    /// The Background rail's three options.
    enum BackgroundOption: Equatable {
        case gradient, colour, image
    }

    /// D14: an image → Image; no gradient, or a hidden one → Colour; otherwise Gradient.
    static func backgroundOption(of doc: ActivityDocument) -> BackgroundOption {
        let background = doc.background
        if background.image != nil { return .image }
        guard let gradient = background.gradient, !gradient.hidden else { return .colour }
        return .gradient
    }

    /// D13: the colours a stored gradient was made from — its base, then its distinct blob colours in order.
    static func paletteColours(of gradient: ActivityBackground.Gradient) -> [String] {
        var colours = [gradient.base]
        for blob in gradient.blobs where !colours.contains(blob.color) { colours.append(blob.color) }
        return colours
    }

    /// Gradient: removes the image and wash (D18); shows the stored gradient with `color = base` (D17),
    /// or generates one from a random palette when the document has none (D14).
    static func showingGradient<R: RandomNumberGenerator>(in doc: ActivityDocument, rng: inout R) -> ActivityDocument {
        var gradient = doc.background.gradient
            ?? ActivityBackgroundGenerator.make(palette: ActivityBackgroundGenerator.randomPalette(rng: &rng), rng: &rng)
        gradient.hidden = false
        return writing(gradient, removingImage: true, to: doc)
    }

    /// Colour: `color` = the pick, a stored gradient is kept but hidden (D14), the image and wash go (D18).
    static func choosingColour(_ hex: String, in doc: ActivityDocument) -> ActivityDocument {
        doc.updating { raw in
            raw[path: ["background", "color"]] = .string(hex)
            if raw[path: ["background", "gradient"]] != nil {
                raw[path: ["background", "gradient", "hidden"]] = .bool(true)
            }
            raw[path: ["background", "image"]] = nil
            raw[path: ["background", "wash"]] = nil
        }
    }

    /// Shuffle: a new layout from the stored gradient's own colours (D13); shows it.
    static func shuffling<R: RandomNumberGenerator>(in doc: ActivityDocument, rng: inout R) -> ActivityDocument {
        guard let current = doc.background.gradient else { return showingGradient(in: doc, rng: &rng) }
        let gradient = ActivityBackgroundGenerator.make(palette: paletteColours(of: current), rng: &rng)
        return writing(gradient, removingImage: false, to: doc)
    }

    /// A palette chip: a new gradient from that palette (D13); shows it.
    static func choosingPalette<R: RandomNumberGenerator>(_ palette: [String], in doc: ActivityDocument, rng: inout R) -> ActivityDocument {
        writing(ActivityBackgroundGenerator.make(palette: palette, rng: &rng), removingImage: false, to: doc)
    }

    /// Writes a visible gradient and `color = base`, keeping every unknown key inside the stored gradient.
    private static func writing(_ gradient: ActivityBackground.Gradient, removingImage: Bool, to doc: ActivityDocument) -> ActivityDocument {
        doc.updating { raw in
            raw[path: ["background", "color"]] = .string(gradient.base)
            if case .object(var stored) = raw[path: ["background", "gradient"]] ?? .null,
               case .object(let fresh) = gradient.jsonValue {
                for (key, value) in fresh { stored[key] = value }
                stored["hidden"] = nil
                raw[path: ["background", "gradient"]] = .object(stored)
            } else {
                raw[path: ["background", "gradient"]] = gradient.jsonValue
            }
            if removingImage {
                raw[path: ["background", "image"]] = nil
                raw[path: ["background", "wash"]] = nil
            }
        }
    }

    /// D40: the picked image becomes the page's background image, keeping a focal point already set.
    static func settingBackgroundImage(mediaId: String, in doc: ActivityDocument) -> ActivityDocument {
        doc.updating { raw in
            raw[path: ["background", "image", "mediaId"]] = .string(mediaId)
            if raw[path: ["background", "image", "focal"]] == nil {
                raw[path: ["background", "image", "focal"]] = .object(["x": .number(0.5), "y": .number(0.5)])
            }
        }
    }

    /// The Actions sheet's list replaces the actions this build draws, in the sheet's order, each kept
    /// over its own raw JSON (unknown fields stay); actions of a kind this build can't draw follow.
    static func applyActions(_ actions: [ActivitiesEditorScreen.PageAction], to doc: ActivityDocument) -> ActivityDocument {
        let existing = rawActions(doc)
        let knownKinds = Set(ActivitiesEditorScreen.PageAction.Kind.allCases.map(\.rawValue))
        let unknown = existing.filter { string($0, "kind").map { !knownKinds.contains($0) } ?? true }
        let edited: [JSONValue] = actions.map { action in
            var value = existing.first { string($0, "id") == action.id } ?? .object([:])
            value[path: ["id"]] = .string(action.id)
            value[path: ["kind"]] = .string(action.kind.rawValue)
            value[path: ["label"]] = .string(action.label)
            value[path: ["placement"]] = .string(action.placement.rawValue)
            // The server requires `payload` on every action, Next lesson's included.
            if case .object? = value[path: ["payload"]] {} else { value[path: ["payload"]] = .object([:]) }
            switch action.kind {
            case .addToPrayerList:
                value[path: ["payload", "title"]] = .string(action.value)
                value[path: ["payload", "body"]] = .string(action.body)
            case .write:
                value[path: ["payload", "prompt"]] = .string(action.value)
            case .openUrl:
                value[path: ["payload", "url"]] = .string(action.value)
            case .nextLesson:
                break
            }
            return value
        }
        return doc.updating { $0[path: ["actions"]] = .array(edited + unknown) }
    }

    /// `#RRGGBB` of a colour the screen hands back (the leader's data; its swatches are hex presets).
    static func hex(_ color: Color) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    // MARK: - Internals

    static func rawObjects(_ doc: ActivityDocument) -> [JSONValue] {
        if case .array(let items)? = doc.raw[path: ["content", "objects"]] { return items }
        return []
    }

    private static func rawActions(_ doc: ActivityDocument) -> [JSONValue] {
        if case .array(let items)? = doc.raw[path: ["actions"]] { return items }
        return []
    }

    private static func string(_ value: JSONValue, _ key: String) -> String? {
        if case .string(let text)? = value[path: [.key(key)]] { return text }
        return nil
    }

    private static func number(_ value: JSONValue, _ key: String) -> Double? {
        if case .number(let number)? = value[path: [.key(key)]] { return number }
        return nil
    }

    /// The Actions sheet's prefill: the kind's first field and the prayer body (02 §7).
    private static func prefill(_ action: ActivityAction) -> (value: String, body: String) {
        let payload = action.payload ?? .null
        func field(_ key: String) -> String {
            if case .string(let text)? = payload[path: [.key(key)]] { return text }
            return ""
        }
        switch action.kind {
        case .addToPrayerList: return (field("title"), field("body"))
        case .write: return (field("prompt"), "")
        case .openUrl: return (field("url"), "")
        case .nextLesson: return ("", "")
        }
    }

    /// Whether a `#RRGGBB` page colour is light (relative luminance over one half).
    private static func isLight(_ hex: String) -> Bool {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return false }
        let red = Double((rgb >> 16) & 0xFF) / 255, green = Double((rgb >> 8) & 0xFF) / 255, blue = Double(rgb & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.5
    }
}
