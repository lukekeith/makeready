import SwiftUI
import UIKit

/// text-activity D26: a lesson rail slide for a canvas kind is the activity's document drawn with C-092 in viewer
/// mode, shrunk to the slide. The page is rendered once per document and put in `Ui2ImageCache` under a synthetic
/// `activity-thumbnail://` key that the program page's slide images carry, so LessonCard draws it like any image.
/// Other kinds keep their poster / thumbnail / empty tile (`StudyProgramHomeMapper.slideImage`).
enum ActivityThumbnail {
    static let scheme = "activity-thumbnail"
    /// The rail slide's frame, in points (C-061 §2).
    static let size = CGSize(width: 33, height: 44)

    private static let referenceWidth: CGFloat = 440
    private static let referenceHeight: CGFloat = 956
    private static let slotWidth: CGFloat = 392

    /// The cache key for a canvas-kind activity's thumbnail; "" for any other kind. It changes with the
    /// document, so an edited activity renders again.
    static func key(for activity: ActivitySummary) -> String {
        guard ActivityEntry.canvasKinds.contains(activity.kind), case .canvas = activity.document.renderable else { return "" }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "slide"
        components.path = "/" + activity.id
        components.queryItems = [URLQueryItem(name: "v", value: String(UInt(bitPattern: activity.document.hashValue)))]
        return components.string ?? ""
    }

    /// Renders and caches each canvas-kind activity's thumbnail that is not cached yet, loading its background
    /// image first (a load that fails leaves the colour alone). Returns whether any landed.
    @MainActor
    static func seed(_ activities: [ActivitySummary], media: [String: MediaMapEntry],
                     fetch: UI2ImageLoader.Fetch = UI2ImageLoader.live, cache: Ui2ImageCache = .shared) async -> Bool {
        var seeded = false
        for activity in activities {
            guard let url = URL(string: key(for: activity)), cache.image(for: url) == nil else { continue }
            var backdrop: UIImage?
            if let imageURL = activity.document.background.image.flatMap({ media[$0.mediaId]?.url }).flatMap(URL.init(string:)) {
                backdrop = try? await fetch(imageURL, 600)
            }
            guard let image = render(activity.document, backgroundImage: backdrop) else { continue }
            cache.seed(image, for: url)
            seeded = true
        }
        return seeded
    }

    /// The document's page, scaled so its width fills the slide and cropped to the slide's height around the middle.
    @MainActor
    static func render(_ document: ActivityDocument, backgroundImage: UIImage?) -> UIImage? {
        guard case .canvas(let canvas) = document.renderable else { return nil }
        let scale = size.width / referenceWidth
        let page = Page(background: document.background, backgroundImage: backgroundImage, objects: canvas.objects)
            .frame(width: referenceWidth, height: referenceHeight)
            .scaleEffect(scale)
            .frame(width: size.width, height: size.height)
            .clipped()
        let renderer = ImageRenderer(content: page)
        renderer.scale = 4
        return renderer.uiImage
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
        let objects: [TextObject]

        var body: some View {
            ZStack(alignment: .topLeading) {
                ActivityThumbnail.color(background.color)
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
                ForEach(objects) { object in
                    CanvasTextObject(
                        text: object.text, mode: .viewer, font: Self.font(object.font), weight: Self.weight(object.weight),
                        size: CGFloat(object.size), color: ActivityThumbnail.color(object.color), alignment: Self.alignment(object.alignment),
                        marks: Self.marks(object.marks),
                        transform: .init(position: CGPoint(x: object.transform.x, y: object.transform.y),
                                         scale: CGFloat(object.transform.scale), rotation: .degrees(object.transform.rotation),
                                         width: CGFloat(object.transform.width)),
                        editing: false
                    )
                    .frame(width: CGFloat(object.transform.width))
                    .position(x: object.transform.x, y: object.transform.y)
                }
            }
            .frame(width: ActivityThumbnail.referenceWidth, height: ActivityThumbnail.referenceHeight, alignment: .topLeading)
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
