import SwiftUI
import UIKit

/// text-activity D26: a lesson rail slide for a canvas kind is the activity's document drawn with C-092 in viewer
/// mode, shrunk to the slide. The page is rendered once per document and put in `Ui2ImageCache` under a synthetic
/// `activity-thumbnail://` key that the program page's slide images carry, so LessonCard draws it like any image.
/// Other kinds keep their poster / thumbnail / empty tile (`StudyProgramHomeMapper.slideImage`).
enum ActivityThumbnail {
    static let scheme = "activity-thumbnail"
    private static let referenceWidth: CGFloat = 440
    private static let referenceHeight: CGFloat = 956

    /// The rail slide's frame, in points: C-079 ActivityScreenshot as LessonCard lays it out — 112 wide,
    /// height from the page's own 440:956 aspect — so the whole page fits exactly, as on the phone.
    static let size = CGSize(width: 112, height: 112 * referenceHeight / referenceWidth)

    /// Bumped whenever the render's geometry changes, so slides cached by an earlier render draw again.
    /// 1 = the 33×44 centre crop (C-061); 2 = the whole page at C-079's size.
    static let renderVersion = 2
    private static let slotWidth: CGFloat = 392

    /// The cache key for a canvas-kind activity's thumbnail; "" for any other kind. It changes with the
    /// document, so an edited activity renders again.
    static func key(for activity: ActivitySummary) -> String {
        guard ActivityEntry.canvasKinds.contains(activity.kind), case .canvas = activity.document.renderable else { return "" }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "slide"
        components.path = "/" + activity.id
        components.queryItems = [URLQueryItem(name: "v", value: String(UInt(bitPattern: activity.document.hashValue))),
                                 URLQueryItem(name: "r", value: String(renderVersion))]
        return components.string ?? ""
    }

    /// Renders and caches each canvas-kind activity's thumbnail that is not cached yet, loading its background
    /// image first (a load that is cancelled or fails caches nothing, so a later seed retries). Returns whether any landed.
    @MainActor
    static func seed(_ activities: [ActivitySummary], media: [String: MediaMapEntry],
                     fetch: UI2ImageLoader.Fetch = UI2ImageLoader.live, cache: Ui2ImageCache = .shared) async -> Bool {
        var seeded = false
        for activity in activities {
            guard let url = URL(string: key(for: activity)), cache.image(for: url) == nil else { continue }
            var backdrop: UIImage?
            if let imageURL = activity.document.background.image.flatMap({ media[$0.mediaId]?.url }).flatMap(URL.init(string:)) {
                do {
                    backdrop = try await fetch(imageURL, 600)
                } catch {
                    // A colour-only page must never be cached under the document's key: it would stand in for the
                    // image for the session. Cancellation ends the pass; a failed load skips this one for a later seed.
                    if UI2ImageLoader.isCancellation(error) { return seeded }
                    continue
                }
            }
            guard let image = render(activity.document, backgroundImage: backdrop) else { continue }
            cache.seed(image, for: url)
            seeded = true
        }
        return seeded
    }

    /// The document's whole page, scaled to the slide — the slide has the page's aspect, so nothing is cropped.
    @MainActor
    static func render(_ document: ActivityDocument, backgroundImage: UIImage?) -> UIImage? {
        guard case .canvas(let canvas) = document.renderable else { return nil }
        let scale = size.width / referenceWidth
        let page = Page(background: document.background, backgroundImage: backgroundImage, objects: objects(for: document))
            .frame(width: referenceWidth, height: referenceHeight)
            .scaleEffect(scale)
            .frame(width: size.width, height: size.height)
            .clipped()
        let renderer = ImageRenderer(content: page)
        renderer.scale = 3   // the phone's screen scale; 336×730 px for a 112pt slide
        return renderer.uiImage
    }

    /// F13: the page's text objects as C-092 draws them in viewer mode — `listStyle`, `startNumber` and highlights kept,
    /// exactly as the player maps them. `reference` is never passed (D10: the citation object is the scripture's only
    /// citation line). Empty for any document that is not a canvas.
    static func objects(for document: ActivityDocument) -> [CanvasTextObject] {
        guard case .canvas(let canvas) = document.renderable else { return [] }
        return canvas.objects.map(Page.canvasObject)
    }

    /// text-activity-v2 D1/D14: the document's gradient as C-091's type — nil when absent or hidden,
    /// so every renderer (editor, viewer, thumbnail) draws exactly the visible gradient.
    static func canvasGradient(_ gradient: ActivityBackground.Gradient?) -> ActivityCanvasGradient? {
        guard let gradient, !gradient.hidden else { return nil }
        return ActivityCanvasGradient(
            base: color(gradient.base),
            hidden: false,
            blobs: gradient.blobs.map { .init(x: $0.x, y: $0.y, r: $0.r, color: color($0.color)) }
        )
    }

    /// Whether the thumbnail draws a gradient layer for this background.
    static func drawsGradient(for background: ActivityBackground) -> Bool {
        canvasGradient(background.gradient) != nil
    }

    /// A colour is the leader's data, read from its `#RRGGBB` (data, not style); anything else is white.
    static func color(_ hex: String) -> Color {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return .white }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }

    private struct Page: View {
        let background: ActivityBackground
        let backgroundImage: UIImage?
        let objects: [CanvasTextObject]

        var body: some View {
            ZStack(alignment: .topLeading) {
                ActivityThumbnail.color(background.color)
                if let gradient = ActivityThumbnail.canvasGradient(background.gradient) {
                    ActivityBlobGradient(gradient: gradient,
                                         pageSize: CGSize(width: ActivityThumbnail.referenceWidth, height: ActivityThumbnail.referenceHeight))
                }
                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: ActivityThumbnail.referenceWidth, height: ActivityThumbnail.referenceHeight)
                        .clipped()
                }
                if let wash = background.wash {
                    ActivityThumbnail.color(wash.color).opacity(wash.opacity)
                }
                ForEach(Array(objects.enumerated()), id: \.offset) { _, object in
                    object
                        .frame(width: object.transform.width)
                        .position(object.transform.position)
                }
            }
            .frame(width: ActivityThumbnail.referenceWidth, height: ActivityThumbnail.referenceHeight, alignment: .topLeading)
        }

        static func canvasObject(_ object: TextObject) -> CanvasTextObject {
            CanvasTextObject(
                text: object.text, mode: .viewer, font: font(object.font), weight: weight(object.weight),
                size: CGFloat(object.size), color: ActivityThumbnail.color(object.color), alignment: alignment(object.alignment),
                listStyle: listStyle(object.listStyle), startNumber: object.startNumber ?? 1,
                marks: marks(object.marks),
                transform: .init(position: CGPoint(x: object.transform.x, y: object.transform.y),
                                 scale: CGFloat(object.transform.scale), rotation: .degrees(object.transform.rotation),
                                 width: CGFloat(object.transform.width)),
                editing: false,
                highlights: object.highlights.map { .init(start: $0.start, end: $0.end, note: $0.noteMarkdown) }
            )
        }

        static func listStyle(_ key: String?) -> CanvasTextObject.ListStyle {
            switch key {
            case "bullet": return .bullet
            case "numbered": return .numbered
            case "bibleVerse": return .bibleVerse
            default: return .none
            }
        }

        // 02 §3/§6: the document's keys, never platform names.
        static func font(_ key: String) -> CanvasTextObject.Font {
            switch key {
            case "display": return .display
            case "serif": return .serif
            case "mono": return .mono
            default: return .sans
            }
        }

        static func weight(_ value: Int) -> CanvasTextObject.Weight {
            switch value {
            case ..<450: return .regular
            case ..<600: return .medium
            default: return .bold
            }
        }

        static func alignment(_ key: String) -> CanvasTextObject.Alignment {
            switch key {
            case "left": return .left
            case "right": return .right
            default: return .center
            }
        }

        static func marks(_ marks: [TextObject.Mark]) -> [CanvasTextObject.Mark] {
            marks.compactMap { mark in
                switch mark.kind {
                case "bold": return .init(start: mark.start, end: mark.end, kind: .bold)
                case "italic": return .init(start: mark.start, end: mark.end, kind: .italic)
                case "link": return mark.href.map { .init(start: mark.start, end: mark.end, kind: .link(href: $0)) }
                default: return nil
                }
            }
        }
    }
}
